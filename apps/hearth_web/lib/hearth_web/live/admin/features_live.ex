defmodule HearthWeb.Admin.FeaturesLive do
  use HearthWeb, :live_view

  alias Hearth.Households

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    household = scope.household

    {:ok,
     assign(socket,
       page_title: "Feature Settings",
       active_nav: :admin_features,
       household: household
     )}
  end

  @impl true
  def handle_event("save", params, socket) do
    features_params = Map.get(params, "features", %{})

    features = %{
      "calendar" => Map.has_key?(features_params, "calendar"),
      "budget" => Map.has_key?(features_params, "budget"),
      "grocery" => Map.has_key?(features_params, "grocery"),
      "inventory" => Map.has_key?(features_params, "inventory"),
      "recipes" => Map.has_key?(features_params, "recipes"),
      "chores" => Map.has_key?(features_params, "chores"),
      "maintenance" => Map.has_key?(features_params, "maintenance"),
      "contacts" => Map.has_key?(features_params, "contacts"),
      "documents" => Map.has_key?(features_params, "documents")
    }

    case Households.update_features(socket.assigns.household, features) do
      {:ok, household} ->
        {:noreply,
         socket
         |> put_flash(:info, "Features updated successfully.")
         |> assign(household: household)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update features.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8 max-w-2xl">
      <h1 class="text-2xl font-semibold mb-6">Feature Settings</h1>
      <p class="text-secondary text-sm mb-6">
        Enable or disable features for your household. Disabled features are hidden from the sidebar and dashboard.
      </p>

      <form phx-submit="save">
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body gap-4">
            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <input
                  type="checkbox"
                  name="features[calendar]"
                  class="checkbox checkbox-primary"
                  checked={Map.get(@household.features || %{}, "calendar", false)}
                />
                <div>
                  <span class="label-text font-medium">Calendar</span>
                  <p class="text-xs text-secondary">Track household events and appointments</p>
                </div>
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <input
                  type="checkbox"
                  name="features[budget]"
                  class="checkbox checkbox-primary"
                  checked={Map.get(@household.features || %{}, "budget", false)}
                />
                <div>
                  <span class="label-text font-medium">Budget</span>
                  <p class="text-xs text-secondary">Manage income, expenses, and categories</p>
                </div>
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <input
                  type="checkbox"
                  name="features[grocery]"
                  class="checkbox checkbox-primary"
                  checked={Map.get(@household.features || %{}, "grocery", false)}
                />
                <div>
                  <span class="label-text font-medium">Grocery Lists</span>
                  <p class="text-xs text-secondary">Shared shopping lists for the household</p>
                </div>
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <input
                  type="checkbox"
                  name="features[inventory]"
                  class="checkbox checkbox-primary"
                  checked={Map.get(@household.features || %{}, "inventory", false)}
                />
                <div>
                  <span class="label-text font-medium">Inventory</span>
                  <p class="text-xs text-secondary">
                    Track household item quantities and get low-stock alerts
                  </p>
                </div>
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <input
                  type="checkbox"
                  name="features[recipes]"
                  class="checkbox checkbox-primary"
                  checked={Map.get(@household.features || %{}, "recipes", false)}
                />
                <div>
                  <span class="label-text font-medium">Recipes</span>
                  <p class="text-xs text-secondary">
                    Store recipes with ingredients, steps, and tags
                  </p>
                </div>
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <input
                  type="checkbox"
                  name="features[chores]"
                  class="checkbox checkbox-primary"
                  checked={Map.get(@household.features || %{}, "chores", false)}
                />
                <div>
                  <span class="label-text font-medium">Chores</span>
                  <p class="text-xs text-secondary">
                    Track recurring household chores with completion history
                  </p>
                </div>
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <input
                  type="checkbox"
                  name="features[maintenance]"
                  class="checkbox checkbox-primary"
                  checked={Map.get(@household.features || %{}, "maintenance", false)}
                />
                <div>
                  <span class="label-text font-medium">Home Maintenance</span>
                  <p class="text-xs text-secondary">
                    Log appliance and vehicle service history with next-due reminders
                  </p>
                </div>
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <input
                  type="checkbox"
                  name="features[contacts]"
                  class="checkbox checkbox-primary"
                  checked={Map.get(@household.features || %{}, "contacts", false)}
                />
                <div>
                  <span class="label-text font-medium">Contacts</span>
                  <p class="text-xs text-secondary">
                    Shared household phone book for plumbers, doctors, and more
                  </p>
                </div>
              </label>
            </div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <input
                  type="checkbox"
                  name="features[documents]"
                  class="checkbox checkbox-primary"
                  checked={Map.get(@household.features || %{}, "documents", false)}
                />
                <div>
                  <span class="label-text font-medium">Document Vault</span>
                  <p class="text-xs text-secondary">
                    Track important documents with expiry date reminders
                  </p>
                </div>
              </label>
            </div>
          </div>
        </div>

        <div class="mt-4 flex justify-end">
          <button type="submit" class="btn btn-primary">Save Changes</button>
        </div>
      </form>
    </div>
    """
  end
end
