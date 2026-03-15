defmodule HearthWeb.ContactsLive.ContactFormComponent do
  use HearthWeb, :live_component

  alias HearthContacts.Contacts

  @impl true
  def update(assigns, socket) do
    contact = assigns.contact
    changeset = Contacts.change_contact(assigns.scope, contact)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(changeset, action: nil))}
  end

  @impl true
  def handle_event("validate", %{"contact" => params}, socket) do
    changeset = Contacts.change_contact(socket.assigns.scope, socket.assigns.contact, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"contact" => params}, socket) do
    scope = socket.assigns.scope
    contact = socket.assigns.contact

    result =
      if contact.id do
        Contacts.update_contact(scope, contact, params)
      else
        Contacts.create_contact(scope, params)
      end

    case result do
      {:ok, saved} ->
        send(self(), {__MODULE__, :saved, saved})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} phx-target={@myself} phx-change="validate" phx-submit="save">
        <div class="space-y-4">
          <.input field={@form[:name]} label="Name" placeholder="Full name" required />
          <.input field={@form[:role]} label="Role" placeholder="e.g. Plumber, Doctor" />
          <.input field={@form[:category]} label="Category" placeholder="e.g. Home Services, Medical" />
          <.input field={@form[:phone]} label="Phone" placeholder="+1 (555) 000-0000" />
          <.input field={@form[:email]} label="Email" type="email" placeholder="name@example.com" />
          <.input field={@form[:address]} label="Address" type="textarea" placeholder="Street, City, State" />
          <.input field={@form[:notes]} label="Notes" type="textarea" />
          <.input field={@form[:is_favorite]} label="Mark as favorite" type="checkbox" />
        </div>
        <div class="flex gap-2 mt-6">
          <.button type="submit" variant="primary" class="flex-1">
            {if @contact && @contact.id, do: "Save Changes", else: "Add Contact"}
          </.button>
        </div>
      </.form>
    </div>
    """
  end
end
