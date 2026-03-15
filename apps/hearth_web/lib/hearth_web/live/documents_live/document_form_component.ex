defmodule HearthWeb.DocumentsLive.DocumentFormComponent do
  use HearthWeb, :live_component

  alias HearthDocuments.Documents

  @impl true
  def update(assigns, socket) do
    document = assigns.document
    changeset = Documents.change_document(assigns.scope, document)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(changeset, action: nil))}
  end

  @impl true
  def handle_event("validate", %{"document" => params}, socket) do
    changeset = Documents.change_document(socket.assigns.scope, socket.assigns.document, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"document" => params}, socket) do
    scope = socket.assigns.scope
    document = socket.assigns.document

    result =
      if document.id do
        Documents.update_document(scope, document, params)
      else
        Documents.create_document(scope, params)
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
          <.input field={@form[:name]} label="Name" placeholder="Document name" required />
          <.input field={@form[:category]} label="Category" placeholder="e.g. Identity, Insurance, Vehicle" />
          <.input field={@form[:document_number]} label="Document Number" placeholder="Policy #, Passport #, etc." />
          <.input field={@form[:expiry_date]} label="Expiry Date" type="date" />
          <.input
            field={@form[:location_hint]}
            label="Location"
            placeholder="e.g. Filing cabinet, top drawer"
          />
          <.input field={@form[:notes]} label="Notes" type="textarea" />
        </div>
        <div class="flex gap-2 mt-6">
          <.button type="submit" variant="primary" class="flex-1">
            {if @document && @document.id, do: "Save Changes", else: "Add Document"}
          </.button>
        </div>
      </.form>
    </div>
    """
  end
end
