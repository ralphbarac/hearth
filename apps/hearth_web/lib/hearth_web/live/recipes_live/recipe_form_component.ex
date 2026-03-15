defmodule HearthWeb.RecipesLive.RecipeFormComponent do
  use HearthWeb, :live_component

  alias HearthRecipes.{Recipes, Tags}

  @impl true
  def update(%{recipe: recipe, scope: scope} = _assigns, socket) do
    tags = Tags.list_tags(scope)
    selected_tag_ids = MapSet.new((recipe.tags || []) |> Enum.map(& &1.id))
    changeset = Recipes.change_recipe(recipe)

    {:ok,
     socket
     |> assign(:scope, scope)
     |> assign(:recipe, recipe)
     |> assign(:tags, tags)
     |> assign(:selected_tag_ids, selected_tag_ids)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("toggle_tag", %{"id" => tag_id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected_tag_ids, tag_id) do
        MapSet.delete(socket.assigns.selected_tag_ids, tag_id)
      else
        MapSet.put(socket.assigns.selected_tag_ids, tag_id)
      end

    {:noreply, assign(socket, :selected_tag_ids, selected)}
  end

  def handle_event("validate", %{"recipe" => params}, socket) do
    changeset =
      socket.assigns.recipe
      |> Recipes.change_recipe(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"recipe" => params}, socket) do
    save_recipe(socket, socket.assigns.recipe.id, params)
  end

  defp save_recipe(socket, nil, params) do
    case Recipes.create_recipe(socket.assigns.scope, params) do
      {:ok, recipe} ->
        tag_ids = MapSet.to_list(socket.assigns.selected_tag_ids)
        {:ok, recipe} = Recipes.set_tags(socket.assigns.scope, recipe, tag_ids)
        send(self(), {__MODULE__, :saved, recipe})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_recipe(socket, _id, params) do
    case Recipes.update_recipe(socket.assigns.scope, socket.assigns.recipe, params) do
      {:ok, recipe} ->
        tag_ids = MapSet.to_list(socket.assigns.selected_tag_ids)
        {:ok, recipe} = Recipes.set_tags(socket.assigns.scope, recipe, tag_ids)
        send(self(), {__MODULE__, :saved, recipe})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "recipe"))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:description]} type="textarea" label="Description" />
        <.input field={@form[:servings]} type="number" label="Servings" min="1" />
        <.input field={@form[:prep_time_minutes]} type="number" label="Prep Time (minutes)" min="0" />
        <.input field={@form[:cook_time_minutes]} type="number" label="Cook Time (minutes)" min="0" />
        <.input field={@form[:notes]} type="textarea" label="Notes" />

        <div :if={@tags != []} class="mt-3">
          <p class="text-sm font-medium mb-2">Tags</p>
          <div class="flex flex-wrap gap-2">
            <label
              :for={tag <- @tags}
              class={[
                "badge cursor-pointer select-none",
                if(MapSet.member?(@selected_tag_ids, tag.id),
                  do: "badge-primary",
                  else: "badge-outline"
                )
              ]}
            >
              <input
                type="checkbox"
                class="hidden"
                phx-click="toggle_tag"
                phx-value-id={tag.id}
                phx-target={@myself}
                checked={MapSet.member?(@selected_tag_ids, tag.id)}
              />
              {tag.name}
            </label>
          </div>
        </div>

        <div class="mt-4">
          <.button type="submit" variant="primary" phx-disable-with="Saving...">Save Recipe</.button>
        </div>
      </.form>
    </div>
    """
  end
end
