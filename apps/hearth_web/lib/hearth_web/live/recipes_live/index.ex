defmodule HearthWeb.RecipesLive.Index do
  use HearthWeb, :live_view

  alias HearthRecipes.{Recipes, Tags, Recipe}
  alias HearthWeb.RecipesLive.RecipeFormComponent
  alias Hearth.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if not Accounts.feature_enabled?(scope, "recipes") do
      {:ok,
       socket
       |> put_flash(:error, "Recipes is not enabled for your account.")
       |> redirect(to: ~p"/dashboard")}
    else
      if connected?(socket), do: Recipes.subscribe(scope)

      {:ok,
       socket
       |> assign(
         page_title: "Recipes",
         active_nav: :recipes,
         tags: Tags.list_tags(scope),
         selected_tag_id: nil,
         show_form: false,
         editing_recipe: nil
       )
       |> load_recipes()}
    end
  end

  @impl true
  def handle_event("new_recipe", _params, socket) do
    {:noreply, assign(socket, show_form: true, editing_recipe: %Recipe{tags: []})}
  end

  def handle_event("edit_recipe", %{"id" => id}, socket) do
    recipe = Recipes.get_recipe!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, show_form: true, editing_recipe: recipe)}
  end

  def handle_event("delete_recipe", %{"id" => id}, socket) do
    recipe = Recipes.get_recipe!(socket.assigns.current_scope, id)
    {:ok, _} = Recipes.delete_recipe(socket.assigns.current_scope, recipe)

    {:noreply,
     socket
     |> put_flash(:info, "Recipe deleted.")
     |> load_recipes()}
  end

  def handle_event("filter_tag", %{"id" => id}, socket) do
    selected = if socket.assigns.selected_tag_id == id, do: nil, else: id
    {:noreply, socket |> assign(selected_tag_id: selected) |> load_recipes()}
  end

  def handle_event("clear_filter", _params, socket) do
    {:noreply, socket |> assign(selected_tag_id: nil) |> load_recipes()}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_recipe: nil)}
  end

  @impl true
  def handle_info({RecipeFormComponent, :saved, _recipe}, socket) do
    {:noreply,
     socket
     |> assign(show_form: false, editing_recipe: nil)
     |> assign(tags: Tags.list_tags(socket.assigns.current_scope))
     |> load_recipes()}
  end

  def handle_info({Recipes, _action, _}, socket) do
    {:noreply, load_recipes(socket)}
  end

  defp load_recipes(socket) do
    scope = socket.assigns.current_scope
    selected_tag_id = socket.assigns.selected_tag_id

    recipes =
      if selected_tag_id do
        Recipes.list_recipes_by_tag(scope, selected_tag_id)
      else
        Recipes.list_recipes(scope)
      end

    assign(socket, recipes: recipes)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <.header>
        Recipes
        <:actions>
          <.button phx-click="new_recipe" variant="primary">New Recipe</.button>
        </:actions>
      </.header>

      <%!-- Tag filter bar --%>
      <div :if={@tags != []} class="mt-4 flex flex-wrap gap-2 items-center">
        <span class="text-sm text-base-content/60">Filter:</span>
        <button
          :for={tag <- @tags}
          phx-click="filter_tag"
          phx-value-id={tag.id}
          class={[
            "badge cursor-pointer",
            if(@selected_tag_id == tag.id, do: "badge-primary", else: "badge-outline")
          ]}
        >
          {tag.name}
        </button>
        <button :if={@selected_tag_id} phx-click="clear_filter" class="btn btn-ghost btn-xs">
          Clear
        </button>
      </div>

      <div class="mt-6 flex gap-6">
        <div class={["flex-1 min-w-0", @show_form && "hidden md:block"]}>
          <%= if @recipes == [] do %>
            <.empty_state icon="hero-book-open" message="No recipes yet. Add your first recipe!" />
          <% else %>
            <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <div
                :for={recipe <- @recipes}
                class="card bg-base-100 border border-base-200 shadow-sm hover:shadow-md transition-shadow"
              >
                <div class="card-body p-4">
                  <.link navigate={~p"/recipes/#{recipe.id}"} class="flex-1">
                    <h3 class="font-semibold text-base truncate">{recipe.name}</h3>
                    <p :if={recipe.description} class="text-sm text-base-content/60 mt-1 line-clamp-2">
                      {recipe.description}
                    </p>
                    <div class="flex flex-wrap gap-1 mt-2">
                      <span :if={recipe.prep_time_minutes} class="text-xs text-base-content/50">
                        Prep: {recipe.prep_time_minutes}m
                      </span>
                      <span :if={recipe.cook_time_minutes} class="text-xs text-base-content/50">
                        Cook: {recipe.cook_time_minutes}m
                      </span>
                      <span :if={recipe.servings} class="text-xs text-base-content/50">
                        Serves: {recipe.servings}
                      </span>
                    </div>
                    <div class="flex flex-wrap gap-1 mt-2">
                      <span :for={tag <- recipe.tags} class="badge badge-sm badge-outline">
                        {tag.name}
                      </span>
                    </div>
                  </.link>
                  <div class="flex gap-1 mt-3">
                    <.button
                      phx-click="edit_recipe"
                      phx-value-id={recipe.id}
                      class="btn btn-ghost btn-xs"
                    >
                      Edit
                    </.button>
                    <.button
                      phx-click="delete_recipe"
                      phx-value-id={recipe.id}
                      data-confirm="Delete this recipe?"
                      class="btn btn-ghost btn-xs text-error"
                    >
                      Delete
                    </.button>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <div :if={@show_form} class="w-full md:w-96 shrink-0">
          <div class="flex items-center gap-2 mb-4 md:hidden">
            <.button phx-click="close_form" class="btn btn-ghost btn-sm btn-circle" aria-label="Back">
              <.icon name="hero-arrow-left" class="size-4" />
            </.button>
            <span class="font-medium">
              {if @editing_recipe && @editing_recipe.id, do: "Edit Recipe", else: "New Recipe"}
            </span>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-4">
                <h3 class="font-semibold text-lg">
                  {if @editing_recipe && @editing_recipe.id, do: "Edit Recipe", else: "New Recipe"}
                </h3>
                <.button
                  phx-click="close_form"
                  class="btn btn-ghost btn-sm btn-circle"
                  aria-label="Close"
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </.button>
              </div>
              <.live_component
                module={RecipeFormComponent}
                id={(@editing_recipe && @editing_recipe.id) || "new-recipe"}
                recipe={@editing_recipe}
                scope={@current_scope}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
