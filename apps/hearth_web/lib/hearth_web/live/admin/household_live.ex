defmodule HearthWeb.Admin.HouseholdLive do
  use HearthWeb, :live_view

  alias Hearth.Households

  @impl true
  def mount(_params, _session, socket) do
    household = socket.assigns.current_scope.household
    changeset = Households.change_household(household)

    {:ok,
     assign(socket,
       page_title: "Household Settings",
       household: household,
       form: to_form(changeset)
     )}
  end

  @impl true
  def handle_event("validate", %{"household" => params}, socket) do
    changeset =
      socket.assigns.household
      |> Households.change_household(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"household" => params}, socket) do
    case Households.update_household(socket.assigns.household, params) do
      {:ok, household} ->
        {:noreply,
         socket
         |> assign(household: household)
         |> put_flash(:info, "Household updated.")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8 max-w-lg">
      <.header>
        Household Settings
      </.header>

      <.form for={@form} phx-change="validate" phx-submit="save" class="mt-6 space-y-4">
        <.input field={@form[:name]} type="text" label="Household name" required />
        <div>
          <.button class="btn btn-primary">Save Changes</.button>
        </div>
      </.form>
    </div>
    """
  end
end
