defmodule HearthWeb.RecipesLive.Show do
  use HearthWeb, :live_view

  alias HearthRecipes.Recipes
  alias HearthWeb.RecipesLive.RecipeFormComponent
  alias Hearth.Accounts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope

    if not Accounts.feature_enabled?(scope, "recipes") do
      {:ok,
       socket
       |> put_flash(:error, "Recipes is not enabled for your account.")
       |> redirect(to: ~p"/dashboard")}
    else
      if connected?(socket), do: Recipes.subscribe(scope)

      recipe = Recipes.get_recipe!(scope, id)

      grocery_lists =
        if Accounts.feature_enabled?(scope, "grocery") do
          HearthGrocery.GroceryLists.list_grocery_lists(scope)
        else
          []
        end

      {:ok,
       socket
       |> assign(
         page_title: recipe.name,
         active_nav: :recipes,
         recipe: recipe,
         show_recipe_form: false,
         grocery_lists: grocery_lists,
         show_grocery_modal: false,
         selected_list_id: (grocery_lists != [] && hd(grocery_lists).id) || nil,
         editing_ingredient_id: nil,
         adding_ingredient: false,
         editing_step_id: nil,
         adding_step: false
       )}
    end
  end

  @impl true
  def handle_event("edit_recipe", _params, socket) do
    {:noreply, assign(socket, show_recipe_form: true)}
  end

  def handle_event("delete_recipe", _params, socket) do
    {:ok, _} = Recipes.delete_recipe(socket.assigns.current_scope, socket.assigns.recipe)

    {:noreply,
     socket
     |> put_flash(:info, "Recipe deleted.")
     |> push_navigate(to: ~p"/recipes")}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_recipe_form: false)}
  end

  # Ingredients
  def handle_event("add_ingredient", _params, socket) do
    {:noreply, assign(socket, adding_ingredient: true)}
  end

  def handle_event("cancel_ingredient", _params, socket) do
    {:noreply, assign(socket, adding_ingredient: false, editing_ingredient_id: nil)}
  end

  def handle_event("save_new_ingredient", params, socket) do
    scope = socket.assigns.current_scope
    recipe = socket.assigns.recipe

    case Recipes.add_ingredient(scope, recipe, params) do
      {:ok, _ingredient} ->
        {:noreply,
         socket
         |> assign(adding_ingredient: false)
         |> reload_recipe()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not add ingredient.")}
    end
  end

  def handle_event("edit_ingredient", %{"id" => id}, socket) do
    {:noreply, assign(socket, editing_ingredient_id: id)}
  end

  def handle_event("save_ingredient", %{"ingredient_id" => id} = params, socket) do
    scope = socket.assigns.current_scope
    ingredient = Enum.find(socket.assigns.recipe.ingredients, &(&1.id == id))

    case Recipes.update_ingredient(scope, ingredient, params) do
      {:ok, _} ->
        {:noreply, socket |> assign(editing_ingredient_id: nil) |> reload_recipe()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update ingredient.")}
    end
  end

  def handle_event("delete_ingredient", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    ingredient = Enum.find(socket.assigns.recipe.ingredients, &(&1.id == id))
    {:ok, _} = Recipes.delete_ingredient(scope, ingredient)
    {:noreply, reload_recipe(socket)}
  end

  # Steps
  def handle_event("add_step", _params, socket) do
    {:noreply, assign(socket, adding_step: true)}
  end

  def handle_event("cancel_step", _params, socket) do
    {:noreply, assign(socket, adding_step: false, editing_step_id: nil)}
  end

  def handle_event("save_new_step", params, socket) do
    scope = socket.assigns.current_scope
    recipe = socket.assigns.recipe
    next_step_number = length(recipe.steps) + 1

    case Recipes.add_step(scope, recipe, Map.put(params, "step_number", next_step_number)) do
      {:ok, _step} ->
        {:noreply,
         socket
         |> assign(adding_step: false)
         |> reload_recipe()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not add step.")}
    end
  end

  def handle_event("edit_step", %{"id" => id}, socket) do
    {:noreply, assign(socket, editing_step_id: id)}
  end

  def handle_event("save_step", %{"step_id" => id} = params, socket) do
    scope = socket.assigns.current_scope
    step = Enum.find(socket.assigns.recipe.steps, &(&1.id == id))

    case Recipes.update_step(scope, step, params) do
      {:ok, _} ->
        {:noreply, socket |> assign(editing_step_id: nil) |> reload_recipe()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update step.")}
    end
  end

  def handle_event("delete_step", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    step = Enum.find(socket.assigns.recipe.steps, &(&1.id == id))
    {:ok, _} = Recipes.delete_step(scope, step)
    {:noreply, reload_recipe(socket)}
  end

  # Grocery modal
  def handle_event("show_grocery_modal", _params, socket) do
    {:noreply, assign(socket, show_grocery_modal: true)}
  end

  def handle_event("close_grocery_modal", _params, socket) do
    {:noreply, assign(socket, show_grocery_modal: false)}
  end

  def handle_event("select_grocery_list", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_list_id: id)}
  end

  def handle_event("add_to_grocery", _params, socket) do
    scope = socket.assigns.current_scope
    recipe = socket.assigns.recipe
    list_id = socket.assigns.selected_list_id

    list = HearthGrocery.GroceryLists.get_grocery_list!(scope, list_id)

    Enum.each(recipe.ingredients, fn ingredient ->
      quantity =
        [ingredient.quantity, ingredient.unit] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

      attrs = %{
        "name" => ingredient.name,
        "quantity" => if(quantity == "", do: nil, else: quantity)
      }

      HearthGrocery.GroceryItems.create_item(scope, list, attrs)
    end)

    Hearth.Links.create_link(scope, "recipe", recipe.id, "grocery_list", list_id)

    {:noreply,
     socket
     |> put_flash(:info, "Ingredients added to #{list.name}.")
     |> assign(show_grocery_modal: false)}
  end

  @impl true
  def handle_info({RecipeFormComponent, :saved, recipe}, socket) do
    {:noreply, assign(socket, show_recipe_form: false, recipe: recipe)}
  end

  def handle_info({Recipes, _action, _}, socket) do
    {:noreply, reload_recipe(socket)}
  end

  defp reload_recipe(socket) do
    scope = socket.assigns.current_scope
    recipe = Recipes.get_recipe!(scope, socket.assigns.recipe.id)
    assign(socket, recipe: recipe)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8 max-w-4xl">
      <%!-- Recipe Form Side Panel --%>
      <div
        :if={@show_recipe_form}
        class="fixed inset-0 z-50 flex justify-end bg-black/30"
        phx-click="close_form"
      >
        <div
          class="bg-base-100 w-full max-w-md h-full overflow-y-auto p-6 shadow-xl"
          phx-click-away="close_form"
        >
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-semibold">Edit Recipe</h2>
            <.button phx-click="close_form" class="btn btn-ghost btn-sm btn-circle">
              <.icon name="hero-x-mark" class="size-4" />
            </.button>
          </div>
          <.live_component
            module={RecipeFormComponent}
            id={@recipe.id}
            recipe={@recipe}
            scope={@current_scope}
          />
        </div>
      </div>

      <%!-- Grocery Modal --%>
      <div :if={@show_grocery_modal} class="modal modal-open">
        <div class="modal-box">
          <h3 class="font-bold text-lg mb-4">Add Ingredients to Grocery List</h3>
          <p class="text-sm text-base-content/70 mb-4">
            Select a grocery list to add <strong>{length(@recipe.ingredients)}</strong> ingredient(s):
          </p>
          <select
            class="select select-bordered w-full mb-4"
            phx-change="select_grocery_list"
            name="id"
          >
            <option
              :for={list <- @grocery_lists}
              value={list.id}
              selected={list.id == @selected_list_id}
            >
              {list.name}
            </option>
          </select>
          <div class="modal-action">
            <button type="button" phx-click="add_to_grocery" class="btn btn-primary">
              Add to List
            </button>
            <button type="button" phx-click="close_grocery_modal" class="btn">Cancel</button>
          </div>
        </div>
        <div class="modal-backdrop" phx-click="close_grocery_modal"></div>
      </div>

      <%!-- Header --%>
      <div class="flex items-start justify-between gap-4 mb-6">
        <div>
          <.link
            navigate={~p"/recipes"}
            class="text-sm text-base-content/50 hover:text-base-content flex items-center gap-1 mb-2"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Recipes
          </.link>
          <h1 class="text-2xl font-bold">{@recipe.name}</h1>
          <div class="flex flex-wrap gap-1 mt-2">
            <span :for={tag <- @recipe.tags} class="badge badge-sm badge-outline">{tag.name}</span>
          </div>
          <div class="flex gap-4 mt-2 text-sm text-base-content/60">
            <span :if={@recipe.servings}>Serves {Kernel.to_string(@recipe.servings)}</span>
            <span :if={@recipe.prep_time_minutes}>Prep: {@recipe.prep_time_minutes}m</span>
            <span :if={@recipe.cook_time_minutes}>Cook: {@recipe.cook_time_minutes}m</span>
          </div>
        </div>
        <div class="flex gap-2 shrink-0">
          <.button phx-click="edit_recipe" class="btn btn-ghost btn-sm">Edit</.button>
          <.button
            phx-click="delete_recipe"
            data-confirm="Delete this recipe?"
            class="btn btn-ghost btn-sm text-error"
          >
            Delete
          </.button>
        </div>
      </div>

      <p :if={@recipe.description} class="text-base-content/70 mb-6">{@recipe.description}</p>
      <p :if={@recipe.notes} class="text-sm text-base-content/50 italic mb-6">{@recipe.notes}</p>

      <div class="grid md:grid-cols-2 gap-8">
        <%!-- Ingredients --%>
        <div>
          <div class="flex items-center justify-between mb-3">
            <h2 class="text-lg font-semibold">Ingredients</h2>
            <div class="flex gap-2">
              <.button
                :if={@grocery_lists != []}
                phx-click="show_grocery_modal"
                class="btn btn-ghost btn-xs"
              >
                Add to Grocery List
              </.button>
              <.button phx-click="add_ingredient" class="btn btn-ghost btn-xs">+ Add</.button>
            </div>
          </div>

          <div
            :if={@recipe.ingredients == [] and not @adding_ingredient}
            class="text-base-content/50 text-sm"
          >
            No ingredients yet.
          </div>

          <ul class="space-y-2">
            <li :for={ingredient <- @recipe.ingredients}>
              <%= if @editing_ingredient_id == ingredient.id do %>
                <form phx-submit="save_ingredient" class="flex gap-2 items-center">
                  <input type="hidden" name="ingredient_id" value={ingredient.id} />
                  <input
                    type="text"
                    name="name"
                    value={ingredient.name}
                    class="input input-bordered input-xs flex-1"
                    placeholder="Name"
                    required
                  />
                  <input
                    type="text"
                    name="quantity"
                    value={ingredient.quantity}
                    class="input input-bordered input-xs w-20"
                    placeholder="Qty"
                  />
                  <input
                    type="text"
                    name="unit"
                    value={ingredient.unit}
                    class="input input-bordered input-xs w-16"
                    placeholder="Unit"
                  />
                  <button type="submit" class="btn btn-xs btn-primary">Save</button>
                  <button type="button" phx-click="cancel_ingredient" class="btn btn-xs">
                    Cancel
                  </button>
                </form>
              <% else %>
                <div class="flex items-center gap-2 group">
                  <span class="flex-1 text-sm">
                    <span :if={ingredient.quantity} class="text-base-content/60">
                      {ingredient.quantity}
                    </span>
                    <span :if={ingredient.unit} class="text-base-content/60">{ingredient.unit}</span>
                    {ingredient.name}
                  </span>
                  <div class="opacity-0 group-hover:opacity-100 flex gap-1">
                    <button
                      phx-click="edit_ingredient"
                      phx-value-id={ingredient.id}
                      class="btn btn-ghost btn-xs"
                    >
                      Edit
                    </button>
                    <button
                      phx-click="delete_ingredient"
                      phx-value-id={ingredient.id}
                      data-confirm="Remove this ingredient?"
                      class="btn btn-ghost btn-xs text-error"
                    >
                      Remove
                    </button>
                  </div>
                </div>
              <% end %>
            </li>
          </ul>

          <form
            :if={@adding_ingredient}
            phx-submit="save_new_ingredient"
            class="mt-3 flex gap-2 items-center"
          >
            <input
              type="text"
              name="name"
              class="input input-bordered input-xs flex-1"
              placeholder="Ingredient name"
              required
            />
            <input
              type="text"
              name="quantity"
              class="input input-bordered input-xs w-20"
              placeholder="Qty"
            />
            <input
              type="text"
              name="unit"
              class="input input-bordered input-xs w-16"
              placeholder="Unit"
            />
            <button type="submit" class="btn btn-xs btn-primary">Add</button>
            <button type="button" phx-click="cancel_ingredient" class="btn btn-xs">Cancel</button>
          </form>
        </div>

        <%!-- Steps --%>
        <div>
          <div class="flex items-center justify-between mb-3">
            <h2 class="text-lg font-semibold">Steps</h2>
            <.button phx-click="add_step" class="btn btn-ghost btn-xs">+ Add</.button>
          </div>

          <div :if={@recipe.steps == [] and not @adding_step} class="text-base-content/50 text-sm">
            No steps yet.
          </div>

          <ol class="space-y-3 list-decimal list-inside">
            <li :for={step <- @recipe.steps}>
              <%= if @editing_step_id == step.id do %>
                <form phx-submit="save_step" class="flex gap-2 items-start mt-1">
                  <input type="hidden" name="step_id" value={step.id} />
                  <textarea
                    name="description"
                    class="textarea textarea-bordered textarea-xs flex-1"
                    rows="2"
                  >{step.description}</textarea>
                  <div class="flex flex-col gap-1">
                    <button type="submit" class="btn btn-xs btn-primary">Save</button>
                    <button type="button" phx-click="cancel_step" class="btn btn-xs">Cancel</button>
                  </div>
                </form>
              <% else %>
                <div class="flex items-start gap-2 group">
                  <span class="flex-1 text-sm">{step.description}</span>
                  <div class="opacity-0 group-hover:opacity-100 flex gap-1 shrink-0">
                    <button phx-click="edit_step" phx-value-id={step.id} class="btn btn-ghost btn-xs">
                      Edit
                    </button>
                    <button
                      phx-click="delete_step"
                      phx-value-id={step.id}
                      data-confirm="Remove this step?"
                      class="btn btn-ghost btn-xs text-error"
                    >
                      Remove
                    </button>
                  </div>
                </div>
              <% end %>
            </li>
          </ol>

          <form :if={@adding_step} phx-submit="save_new_step" class="mt-3 flex gap-2 items-start">
            <textarea
              name="description"
              class="textarea textarea-bordered textarea-xs flex-1"
              placeholder="Describe this step..."
              rows="2"
              required
            ></textarea>
            <div class="flex flex-col gap-1">
              <button type="submit" class="btn btn-xs btn-primary">Add</button>
              <button type="button" phx-click="cancel_step" class="btn btn-xs">Cancel</button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
