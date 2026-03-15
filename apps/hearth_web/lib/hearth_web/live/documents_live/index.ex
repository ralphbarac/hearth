defmodule HearthWeb.DocumentsLive.Index do
  use HearthWeb, :live_view

  alias HearthDocuments.Documents
  alias HearthDocuments.Document
  alias HearthWeb.DocumentsLive.DocumentFormComponent
  alias Hearth.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if not Accounts.feature_enabled?(scope, "documents") do
      {:ok,
       socket
       |> put_flash(:error, "Document Vault is not enabled for your household.")
       |> redirect(to: ~p"/dashboard")}
    else
      if connected?(socket), do: Documents.subscribe(scope)

      {:ok,
       socket
       |> assign(page_title: "Document Vault", active_nav: :documents)
       |> assign(show_form: false, editing_document: nil)
       |> load_documents()}
    end
  end

  @impl true
  def handle_event("new_document", _params, socket) do
    {:noreply, assign(socket, show_form: true, editing_document: %Document{})}
  end

  def handle_event("edit_document", %{"id" => id}, socket) do
    document = Documents.get_document!(socket.assigns.current_scope, id)
    {:noreply, assign(socket, show_form: true, editing_document: document)}
  end

  def handle_event("delete_document", %{"id" => id}, socket) do
    document = Documents.get_document!(socket.assigns.current_scope, id)
    {:ok, _} = Documents.delete_document(socket.assigns.current_scope, document)

    {:noreply,
     socket
     |> put_flash(:info, "Document deleted.")
     |> load_documents()}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_document: nil)}
  end

  @impl true
  def handle_info({DocumentFormComponent, :saved, _document}, socket) do
    {:noreply,
     socket
     |> assign(show_form: false, editing_document: nil)
     |> load_documents()}
  end

  def handle_info({Documents, _action, _document}, socket) do
    {:noreply, load_documents(socket)}
  end

  defp load_documents(socket) do
    scope = socket.assigns.current_scope

    assign(socket,
      documents_by_category: Documents.list_documents_by_category(scope),
      expiring_soon: Documents.list_expiring_soon(scope)
    )
  end

  defp expiry_status(nil), do: :no_expiry

  defp expiry_status(date) do
    today = Date.utc_today()

    cond do
      Date.compare(date, today) == :lt -> :expired
      Date.compare(date, Date.add(today, 90)) != :gt -> :expiring_soon
      true -> :valid
    end
  end

  defp expiry_badge_class(:expired), do: "badge-error"
  defp expiry_badge_class(:expiring_soon), do: "badge-warning"
  defp expiry_badge_class(:valid), do: "badge-success"
  defp expiry_badge_class(:no_expiry), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <.header>
        Document Vault
        <:actions>
          <.button phx-click="new_document" variant="primary">Add Document</.button>
        </:actions>
      </.header>

      <%= if @expiring_soon != [] do %>
        <div class="alert alert-warning mt-4">
          <.icon name="hero-exclamation-triangle" class="size-5" />
          <div>
            <p class="font-medium">
              {length(@expiring_soon)} document{if length(@expiring_soon) != 1, do: "s"} expiring or expired
            </p>
            <p class="text-sm">
              Review documents below with warning or error badges.
            </p>
          </div>
        </div>
      <% end %>

      <div class="mt-6 flex gap-6">
        <div class={["flex-1 min-w-0", @show_form && "hidden md:block"]}>
          <%= if @documents_by_category == %{} do %>
            <.empty_state icon="hero-folder" message="No documents yet. Add your first one!" />
          <% else %>
            <%= for {category, docs} <- Enum.sort_by(@documents_by_category, fn {k, _} -> k end) do %>
              <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60 mb-3 mt-4">
                {category}
              </h2>
              <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 mb-4">
                <%= for doc <- docs do %>
                  <% status = expiry_status(doc.expiry_date) %>
                  <div class="card bg-base-100 border border-base-200 shadow-sm hover:bg-base-200/40 transition-colors">
                    <div class="card-body p-4">
                      <div class="flex items-start justify-between gap-2">
                        <p class="font-semibold truncate flex-1">{doc.name}</p>
                        <%= if expiry_badge_class(status) do %>
                          <span class={["badge badge-sm", expiry_badge_class(status)]}>
                            {if status == :expired, do: "Expired", else: "Exp soon"}
                          </span>
                        <% end %>
                      </div>
                      <%= if doc.document_number do %>
                        <p class="text-xs text-base-content/60 mt-1">#{doc.document_number}</p>
                      <% end %>
                      <%= if doc.expiry_date do %>
                        <p class="text-sm text-base-content/70 mt-1">
                          Expires: {Date.to_string(doc.expiry_date)}
                        </p>
                      <% end %>
                      <%= if doc.location_hint do %>
                        <p class="text-xs text-base-content/50 mt-1 truncate">
                          <.icon name="hero-map-pin" class="size-3 inline mr-1" />{doc.location_hint}
                        </p>
                      <% end %>
                      <div class="flex gap-1 mt-3">
                        <.button
                          phx-click="edit_document"
                          phx-value-id={doc.id}
                          class="btn btn-ghost btn-xs"
                        >
                          Edit
                        </.button>
                        <.button
                          phx-click="delete_document"
                          phx-value-id={doc.id}
                          data-confirm="Delete this document?"
                          class="btn btn-ghost btn-xs text-error"
                        >
                          Delete
                        </.button>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          <% end %>
        </div>

        <div :if={@show_form} class="w-full md:w-96 shrink-0">
          <div class="flex items-center gap-2 mb-4 md:hidden">
            <.button phx-click="close_form" class="btn btn-ghost btn-sm btn-circle" aria-label="Back">
              <.icon name="hero-arrow-left" class="size-4" />
            </.button>
            <span class="font-medium">
              {if @editing_document && @editing_document.id, do: "Edit Document", else: "New Document"}
            </span>
          </div>
          <div class="card bg-base-100 border border-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-4">
                <h3 class="font-semibold text-lg">
                  {if @editing_document && @editing_document.id, do: "Edit Document", else: "New Document"}
                </h3>
                <.button phx-click="close_form" class="btn btn-ghost btn-sm btn-circle" aria-label="Close">
                  <.icon name="hero-x-mark" class="size-4" />
                </.button>
              </div>
              <.live_component
                module={DocumentFormComponent}
                id={(@editing_document && @editing_document.id) || "new"}
                document={@editing_document}
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
