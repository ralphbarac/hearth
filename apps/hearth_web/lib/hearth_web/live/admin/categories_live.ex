defmodule HearthWeb.Admin.CategoriesLive do
  use HearthWeb, :live_view

  alias HearthBudget.{Categories, Category}
  alias HearthRecipes.{Tags, Tag}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:page_title, "Categories & Tags")
     |> assign(:active_nav, :admin_categories)
     |> assign(:scope, scope)
     |> assign(:budget_categories, Categories.list_categories(scope))
     |> assign(:recipe_tags, Tags.list_tags(scope))
     |> assign(:budget_form, nil)
     |> assign(:tag_form, nil)}
  end

  @impl true
  def handle_event("new_budget_category", _params, socket) do
    changeset = Categories.change_category(socket.assigns.scope, %Category{})
    {:noreply, assign(socket, budget_form: to_form(changeset, action: nil))}
  end

  def handle_event("validate_budget_category", %{"category" => params}, socket) do
    changeset = Categories.change_category(socket.assigns.scope, %Category{}, params)
    {:noreply, assign(socket, budget_form: to_form(changeset, action: :validate))}
  end

  def handle_event("save_budget_category", %{"category" => params}, socket) do
    scope = socket.assigns.scope

    case Categories.create_category(scope, params) do
      {:ok, _cat} ->
        {:noreply,
         socket
         |> put_flash(:info, "Category added.")
         |> assign(:budget_categories, Categories.list_categories(scope))
         |> assign(:budget_form, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, budget_form: to_form(changeset, action: :validate))}
    end
  end

  def handle_event("delete_budget_category", %{"id" => id}, socket) do
    scope = socket.assigns.scope
    cat = Enum.find(socket.assigns.budget_categories, &(&1.id == id))

    if cat do
      Categories.delete_category(scope, cat)
    end

    {:noreply,
     socket
     |> assign(:budget_categories, Categories.list_categories(scope))}
  end

  def handle_event("new_tag", _params, socket) do
    changeset = Tags.change_tag(socket.assigns.scope, %Tag{})
    {:noreply, assign(socket, tag_form: to_form(changeset, action: nil))}
  end

  def handle_event("validate_tag", %{"tag" => params}, socket) do
    changeset = Tags.change_tag(socket.assigns.scope, %Tag{}, params)
    {:noreply, assign(socket, tag_form: to_form(changeset, action: :validate))}
  end

  def handle_event("save_tag", %{"tag" => params}, socket) do
    scope = socket.assigns.scope

    case Tags.create_tag(scope, params) do
      {:ok, _tag} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag added.")
         |> assign(:recipe_tags, Tags.list_tags(scope))
         |> assign(:tag_form, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, tag_form: to_form(changeset, action: :validate))}
    end
  end

  def handle_event("delete_tag", %{"id" => id}, socket) do
    scope = socket.assigns.scope
    tag = Enum.find(socket.assigns.recipe_tags, &(&1.id == id))

    if tag do
      Tags.delete_tag(scope, tag)
    end

    {:noreply, assign(socket, :recipe_tags, Tags.list_tags(scope))}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, socket |> assign(:budget_form, nil) |> assign(:tag_form, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8 max-w-3xl space-y-8">
      <h1 class="text-2xl font-semibold">Categories & Tags</h1>

      <%!-- Budget Categories --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h2 class="text-lg font-semibold">Budget Categories</h2>
              <p class="text-sm text-base-content/60">
                Manage income and expense categories for your household.
              </p>
            </div>
            <button
              :if={is_nil(@budget_form)}
              class="btn btn-sm btn-primary"
              phx-click="new_budget_category"
            >
              <.icon name="hero-plus" class="size-4" /> Add
            </button>
          </div>

          <div class="overflow-x-auto">
            <table class="table table-sm">
              <tbody>
                <tr :for={cat <- @budget_categories}>
                  <td class="font-medium">{cat.name}</td>
                  <td>
                    <span class={[
                      "badge badge-sm",
                      if(cat.type == "income", do: "badge-success", else: "badge-error")
                    ]}>
                      {cat.type}
                    </span>
                  </td>
                  <td class="text-right">
                    <button
                      class="btn btn-ghost btn-xs text-error"
                      phx-click="delete_budget_category"
                      phx-value-id={cat.id}
                      data-confirm={"Delete category \"#{cat.name}\"?"}
                    >
                      <.icon name="hero-trash" class="size-4" />
                    </button>
                  </td>
                </tr>
                <tr :if={@budget_categories == []}>
                  <td colspan="4" class="text-center text-base-content/50 py-4">
                    No categories yet.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <%!-- Inline add form --%>
          <div :if={@budget_form} class="mt-4 border-t border-base-300 pt-4">
            <.form
              for={@budget_form}
              phx-change="validate_budget_category"
              phx-submit="save_budget_category"
              class="flex flex-wrap gap-2 items-end"
            >
              <div class="form-control flex-1 min-w-40">
                <label class="label label-text text-xs">Name</label>
                <.input
                  field={@budget_form[:name]}
                  type="text"
                  placeholder="Category name"
                  class="input input-bordered input-sm"
                />
              </div>
              <div class="form-control">
                <label class="label label-text text-xs">Type</label>
                <.input
                  field={@budget_form[:type]}
                  type="select"
                  options={[{"Expense", "expense"}, {"Income", "income"}]}
                  class="select select-bordered select-sm"
                />
              </div>
              <div class="flex gap-2">
                <button type="submit" class="btn btn-sm btn-primary">Save</button>
                <button type="button" class="btn btn-sm btn-ghost" phx-click="close_form">
                  Cancel
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>

      <%!-- Recipe Tags --%>
      <div class="card bg-base-100 border border-base-300 shadow-sm">
        <div class="card-body">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h2 class="text-lg font-semibold">Recipe Tags</h2>
              <p class="text-sm text-base-content/60">
                Manage tags used to organise and filter recipes.
              </p>
            </div>
            <button
              :if={is_nil(@tag_form)}
              class="btn btn-sm btn-primary"
              phx-click="new_tag"
            >
              <.icon name="hero-plus" class="size-4" /> Add
            </button>
          </div>

          <div class="flex flex-wrap gap-2 mb-4">
            <span
              :for={tag <- @recipe_tags}
              class="badge badge-outline gap-1 pr-1"
            >
              {tag.name}
              <button
                class="btn btn-ghost btn-xs p-0 size-4 min-h-0 text-error"
                phx-click="delete_tag"
                phx-value-id={tag.id}
                data-confirm={"Delete tag \"#{tag.name}\"?"}
              >
                <.icon name="hero-x-mark" class="size-3" />
              </button>
            </span>
            <span :if={@recipe_tags == []} class="text-sm text-base-content/50">
              No tags yet.
            </span>
          </div>

          <%!-- Inline add form --%>
          <div :if={@tag_form} class="border-t border-base-300 pt-4">
            <.form
              for={@tag_form}
              phx-change="validate_tag"
              phx-submit="save_tag"
              class="flex gap-2 items-end"
            >
              <div class="form-control flex-1">
                <label class="label label-text text-xs">Tag name</label>
                <.input
                  field={@tag_form[:name]}
                  type="text"
                  placeholder="e.g. vegetarian"
                  class="input input-bordered input-sm"
                />
              </div>
              <div class="flex gap-2">
                <button type="submit" class="btn btn-sm btn-primary">Add</button>
                <button type="button" class="btn btn-sm btn-ghost" phx-click="close_form">
                  Cancel
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
