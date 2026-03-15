defmodule HearthWeb.MealPlanLive do
  use HearthWeb, :live_view

  alias HearthCalendar.Events
  alias HearthRecipes.Recipes
  alias HearthInventory.InventoryItems
  alias HearthGrocery.{GroceryLists, GroceryItems}
  alias Hearth.{Links, Accounts}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    unless Accounts.feature_enabled?(scope, "calendar") and
             Accounts.feature_enabled?(scope, "recipes") do
      {:ok,
       socket
       |> put_flash(:error, "Meal Planner requires both Calendar and Recipes features.")
       |> redirect(to: ~p"/dashboard")}
    else
      {:ok,
       assign(socket,
         page_title: "Meal Planner",
         active_nav: :meal_plan,
         step: 1,
         plan_name: "",
         plan_date: "",
         available_recipes: [],
         selected_recipe_ids: [],
         computed_ingredients: [],
         excluded_ingredient_indices: MapSet.new(),
         grocery_lists: [],
         new_list_name: ""
       )}
    end
  end

  # Step 1: name + date submission
  @impl true
  def handle_event("step_1_submit", %{"plan_name" => name, "plan_date" => date_str}, socket) do
    name = String.trim(name)

    with false <- name == "",
         {:ok, _date} <- Date.from_iso8601(date_str) do
      scope = socket.assigns.current_scope
      available_recipes = Recipes.list_recipes_with_ingredients(scope)
      selected_recipe_ids = Enum.map(available_recipes, & &1.id)

      {:noreply,
       assign(socket,
         step: 2,
         plan_name: name,
         plan_date: date_str,
         available_recipes: available_recipes,
         selected_recipe_ids: selected_recipe_ids
       )}
    else
      true ->
        {:noreply, put_flash(socket, :error, "Please enter a plan name.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Please enter a valid date.")}
    end
  end

  # Step 2: toggle recipe selection
  def handle_event("toggle_recipe", %{"id" => id}, socket) do
    selected =
      if id in socket.assigns.selected_recipe_ids do
        List.delete(socket.assigns.selected_recipe_ids, id)
      else
        [id | socket.assigns.selected_recipe_ids]
      end

    {:noreply, assign(socket, selected_recipe_ids: selected)}
  end

  # Step 2 → Step 3: compute ingredients
  def handle_event("step_2_next", _params, socket) do
    scope = socket.assigns.current_scope

    inventory_items =
      if Accounts.feature_enabled?(scope, "inventory") do
        InventoryItems.list_items(scope)
      else
        []
      end

    selected_recipes =
      Enum.filter(socket.assigns.available_recipes, fn r ->
        r.id in socket.assigns.selected_recipe_ids
      end)

    ingredients = compute_ingredients(selected_recipes, inventory_items)

    {:noreply,
     assign(socket,
       step: 3,
       computed_ingredients: ingredients,
       excluded_ingredient_indices: MapSet.new()
     )}
  end

  # Step 3: toggle ingredient exclusion
  def handle_event("toggle_ingredient", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    excluded = socket.assigns.excluded_ingredient_indices

    excluded =
      if MapSet.member?(excluded, idx) do
        MapSet.delete(excluded, idx)
      else
        MapSet.put(excluded, idx)
      end

    {:noreply, assign(socket, excluded_ingredient_indices: excluded)}
  end

  # Step 3 → Step 4: load grocery lists
  def handle_event("step_3_next", _params, socket) do
    grocery_lists = GroceryLists.list_grocery_lists(socket.assigns.current_scope)

    {:noreply,
     assign(socket,
       step: 4,
       grocery_lists: grocery_lists,
       new_list_name: socket.assigns.plan_name
     )}
  end

  # Step 4: generate calendar events + grocery items
  def handle_event(
        "generate",
        %{"target_list_id" => list_id, "new_list_name" => new_name},
        socket
      ) do
    scope = socket.assigns.current_scope
    excluded = socket.assigns.excluded_ingredient_indices

    active_ingredients =
      socket.assigns.computed_ingredients
      |> Enum.with_index()
      |> Enum.reject(fn {_ing, idx} -> MapSet.member?(excluded, idx) end)
      |> Enum.map(fn {ing, _} -> ing end)

    grocery_list =
      cond do
        String.trim(new_name) != "" ->
          {:ok, list} =
            GroceryLists.create_grocery_list(scope, %{"name" => String.trim(new_name)})

          list

        list_id != "" ->
          GroceryLists.get_grocery_list!(scope, list_id)

        true ->
          nil
      end

    if grocery_list do
      {:ok, plan_date} = Date.from_iso8601(socket.assigns.plan_date)
      starts_at = DateTime.new!(plan_date, ~T[18:00:00], "Etc/UTC") |> DateTime.to_iso8601()

      selected_recipes =
        Enum.filter(socket.assigns.available_recipes, fn r ->
          r.id in socket.assigns.selected_recipe_ids
        end)

      for recipe <- selected_recipes do
        {:ok, event} =
          Events.create_event(scope, %{
            "title" => recipe.name,
            "starts_at" => starts_at,
            "color" => "amber"
          })

        Links.create_link(scope, "calendar_event", event.id, "recipe", recipe.id)
        Links.create_link(scope, "calendar_event", event.id, "grocery_list", grocery_list.id)
      end

      for ingredient <- active_ingredients do
        GroceryItems.create_item(scope, grocery_list, %{
          "name" => ingredient.name,
          "quantity" => ingredient.quantity_str
        })
      end

      {:noreply,
       socket
       |> put_flash(:info, "Meal plan created!")
       |> push_navigate(to: ~p"/grocery")}
    else
      {:noreply, put_flash(socket, :error, "Please select or create a grocery list.")}
    end
  end

  # Back navigation
  def handle_event("step_back", _params, socket) do
    {:noreply, assign(socket, step: socket.assigns.step - 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8 max-w-2xl mx-auto">
      <h1 class="text-2xl font-bold mb-6">Meal Planner</h1>

      <%!-- Step indicator --%>
      <div class="flex items-center gap-2 mb-8">
        <%= for {label, n} <- [{"Plan", 1}, {"Recipes", 2}, {"Ingredients", 3}, {"Grocery List", 4}] do %>
          <div class="flex items-center gap-2">
            <div class={[
              "w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold",
              if(@step == n,
                do: "bg-primary text-primary-content",
                else:
                  if(@step > n,
                    do: "bg-success text-success-content",
                    else: "bg-base-300 text-base-content/50"
                  )
              )
            ]}>
              {n}
            </div>
            <span class={["text-sm hidden sm:inline", @step == n && "font-semibold"]}>{label}</span>
          </div>
          <%= if n < 4 do %>
            <div class="flex-1 h-px bg-base-300 max-w-8"></div>
          <% end %>
        <% end %>
      </div>

      <%!-- Step 1: Plan name + date --%>
      <div :if={@step == 1}>
        <div class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-lg mb-4">New Meal Plan</h2>
            <form phx-submit="step_1_submit" class="space-y-4">
              <div class="form-control">
                <label class="label">
                  <span class="label-text font-medium">Plan name</span>
                </label>
                <input
                  type="text"
                  name="plan_name"
                  value={@plan_name}
                  placeholder="e.g. Week of March 10"
                  class="input input-bordered"
                  required
                />
              </div>
              <div class="form-control">
                <label class="label">
                  <span class="label-text font-medium">Date</span>
                </label>
                <input
                  type="date"
                  name="plan_date"
                  value={@plan_date}
                  class="input input-bordered"
                  required
                />
              </div>
              <div class="flex justify-end">
                <button type="submit" class="btn btn-primary">Next →</button>
              </div>
            </form>
          </div>
        </div>
      </div>

      <%!-- Step 2: Select recipes --%>
      <div :if={@step == 2}>
        <div class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-lg mb-1">Select Recipes</h2>
            <p class="text-sm text-base-content/60 mb-4">
              Choose which recipes to include. A calendar event will be created for each.
            </p>
            <%= if @available_recipes == [] do %>
              <div class="py-8 text-center text-base-content/50">
                <.icon name="hero-book-open" class="size-8 mx-auto mb-2 opacity-40" />
                <p class="text-sm">
                  No recipes yet.
                  <.link href={~p"/recipes"} class="link link-primary">Add some recipes</.link>
                  first.
                </p>
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for recipe <- @available_recipes do %>
                  <label class="flex items-center gap-3 cursor-pointer p-3 rounded-lg hover:bg-base-200/50 border border-base-200">
                    <input
                      type="checkbox"
                      class="checkbox checkbox-sm"
                      checked={recipe.id in @selected_recipe_ids}
                      phx-click="toggle_recipe"
                      phx-value-id={recipe.id}
                    />
                    <div class="flex-1 min-w-0">
                      <p class="font-medium text-sm">{recipe.name}</p>
                      <p class="text-xs text-base-content/50">
                        {length(recipe.ingredients)} ingredient{if length(recipe.ingredients) != 1,
                          do: "s"}
                      </p>
                    </div>
                  </label>
                <% end %>
              </div>
            <% end %>
            <div class="flex justify-between mt-6">
              <button phx-click="step_back" class="btn btn-ghost">← Back</button>
              <button
                phx-click="step_2_next"
                class="btn btn-primary"
                disabled={@selected_recipe_ids == []}
              >
                Next →
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Step 3: Ingredient Review --%>
      <div :if={@step == 3}>
        <div class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-lg mb-1">Review Ingredients</h2>
            <p class="text-sm text-base-content/60 mb-4">
              Uncheck anything you already have or don't need.
            </p>
            <%= if @computed_ingredients == [] do %>
              <p class="text-base-content/50 text-sm">
                The selected recipes have no ingredients. Add some in the Recipes section.
              </p>
            <% else %>
              <div class="overflow-x-auto">
                <table class="table table-sm w-full">
                  <thead>
                    <tr>
                      <th class="w-8"></th>
                      <th>Ingredient</th>
                      <th>Amount</th>
                      <th :if={Enum.any?(@computed_ingredients, & &1.have_qty)}>Have</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {ingredient, idx} <- Enum.with_index(@computed_ingredients) do %>
                      <tr class={MapSet.member?(@excluded_ingredient_indices, idx) && "opacity-40"}>
                        <td>
                          <input
                            type="checkbox"
                            class="checkbox checkbox-sm"
                            checked={not MapSet.member?(@excluded_ingredient_indices, idx)}
                            phx-click="toggle_ingredient"
                            phx-value-index={idx}
                          />
                        </td>
                        <td class="font-medium">{ingredient.name}</td>
                        <td class="text-base-content/70">{ingredient.quantity_str}</td>
                        <td :if={Enum.any?(@computed_ingredients, & &1.have_qty)} class="text-success">
                          {ingredient.have_qty || "—"}
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
            <div class="flex justify-between mt-6">
              <button phx-click="step_back" class="btn btn-ghost">← Back</button>
              <button phx-click="step_3_next" class="btn btn-primary">Next →</button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Step 4: Target Grocery List --%>
      <div :if={@step == 4}>
        <div class="card bg-base-100 border border-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-lg mb-1">Choose Grocery List</h2>
            <p class="text-sm text-base-content/60 mb-4">
              Ingredients will be added to this list.
            </p>
            <form phx-submit="generate" class="space-y-4">
              <%= if @grocery_lists != [] do %>
                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-medium">Add to existing list</span>
                  </label>
                  <select name="target_list_id" class="select select-bordered">
                    <option value="">— none —</option>
                    <%= for list <- @grocery_lists do %>
                      <option value={list.id}>{list.name}</option>
                    <% end %>
                  </select>
                </div>
                <div class="divider text-xs">or create new</div>
              <% else %>
                <input type="hidden" name="target_list_id" value="" />
              <% end %>
              <div class="form-control">
                <label class="label">
                  <span class="label-text font-medium">New list name</span>
                </label>
                <input
                  type="text"
                  name="new_list_name"
                  value={@new_list_name}
                  class="input input-bordered"
                />
              </div>
              <div class="flex justify-between mt-6">
                <button type="button" phx-click="step_back" class="btn btn-ghost">← Back</button>
                <button type="submit" class="btn btn-primary">Generate</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- Private helpers ---

  defp compute_ingredients(selected_recipes, inventory_items) do
    selected_recipes
    |> Enum.flat_map(& &1.ingredients)
    |> Enum.group_by(fn i -> String.downcase(i.name) end)
    |> Enum.map(fn {_key, group} ->
      name = List.first(group).name
      quantity_str = group |> Enum.map(&format_ingredient_qty/1) |> Enum.join(", ")
      have_qty = find_inventory_qty(List.first(group).name, inventory_items)
      %{name: name, quantity_str: quantity_str, have_qty: have_qty}
    end)
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  defp format_ingredient_qty(%{quantity: nil, unit: nil}), do: "—"
  defp format_ingredient_qty(%{quantity: nil, unit: ""}), do: "—"
  defp format_ingredient_qty(%{quantity: qty, unit: nil}), do: qty
  defp format_ingredient_qty(%{quantity: qty, unit: ""}), do: qty
  defp format_ingredient_qty(%{quantity: nil, unit: unit}), do: unit
  defp format_ingredient_qty(%{quantity: qty, unit: unit}), do: "#{qty} #{unit}"

  defp find_inventory_qty(_name, []), do: nil

  defp find_inventory_qty(name, inventory_items) do
    name_lower = String.downcase(name)

    case Enum.find(inventory_items, fn item -> String.downcase(item.name) == name_lower end) do
      nil -> nil
      item -> "#{item.quantity}#{if item.unit && item.unit != "", do: " #{item.unit}", else: ""}"
    end
  end
end
