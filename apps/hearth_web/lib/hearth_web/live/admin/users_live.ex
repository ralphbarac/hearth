defmodule HearthWeb.Admin.UsersLive do
  use HearthWeb, :live_view

  alias Hearth.Accounts
  alias Hearth.Accounts.User

  @all_features ~w(calendar budget grocery inventory recipes chores maintenance contacts documents)
  @feature_labels %{
    "calendar" => "Calendar",
    "budget" => "Budget",
    "grocery" => "Grocery",
    "inventory" => "Inventory",
    "recipes" => "Recipes",
    "chores" => "Chores",
    "maintenance" => "Maintenance",
    "contacts" => "Contacts",
    "documents" => "Documents"
  }

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    users = Accounts.list_household_users(scope)
    blank_changeset = blank_new_member_form()

    {:ok,
     assign(socket,
       page_title: "Manage Users",
       active_nav: :admin_users,
       users: users,
       household: scope.household,
       show_form: false,
       new_member_form: blank_changeset,
       all_features: @all_features,
       feature_labels: @feature_labels
     )}
  end

  @impl true
  def handle_event("new_member", _params, socket) do
    {:noreply, assign(socket, show_form: true)}
  end

  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, new_member_form: blank_new_member_form())}
  end

  def handle_event("validate_member", %{"user" => params}, socket) do
    form =
      %User{}
      |> User.admin_create_changeset(params)
      |> Map.put(:action, :validate)
      |> to_form(as: "user")

    {:noreply, assign(socket, new_member_form: form)}
  end

  def handle_event("create_member", %{"user" => params}, socket) do
    scope = socket.assigns.current_scope
    features_list = Map.get(params, "features", [])
    features_map = Map.new(@all_features, fn k -> {k, k in features_list} end)
    params = Map.put(params, "features", features_map)

    case Accounts.admin_create_user(scope, params) do
      {:ok, _user} ->
        users = Accounts.list_household_users(scope)

        {:noreply,
         socket
         |> assign(users: users, show_form: false, new_member_form: blank_new_member_form())
         |> put_flash(:info, "Member created successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, new_member_form: to_form(changeset, as: "user"))}
    end
  end

  def handle_event("update_role", %{"user-id" => user_id, "role" => role}, socket) do
    scope = socket.assigns.current_scope
    user = Enum.find(socket.assigns.users, &(&1.id == user_id))

    if user do
      case Accounts.update_user_role(scope, user, role) do
        {:ok, _user} ->
          users = Accounts.list_household_users(scope)
          {:noreply, assign(socket, users: users)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Could not update role.")}
      end
    else
      {:noreply, put_flash(socket, :error, "User not found.")}
    end
  end

  def handle_event("delete_user", %{"user-id" => user_id}, socket) do
    user = Enum.find(socket.assigns.users, &(&1.id == user_id))

    if is_nil(user) do
      {:noreply, put_flash(socket, :error, "User not found.")}
    else
      case Accounts.delete_user(socket.assigns.current_scope, user) do
        {:ok, _user} ->
          users = Accounts.list_household_users(socket.assigns.current_scope)

          {:noreply,
           socket
           |> assign(users: users)
           |> put_flash(:info, "User deleted.")}

        {:error, :cannot_delete_self} ->
          {:noreply, put_flash(socket, :error, "You cannot delete yourself.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete user.")}
      end
    end
  end

  def handle_event(
        "save_user_features",
        %{"user_id" => user_id, "features" => features_list},
        socket
      ) do
    scope = socket.assigns.current_scope
    user = Enum.find(socket.assigns.users, &(&1.id == user_id))

    if user do
      features = Map.new(@all_features, fn key -> {key, key in features_list} end)

      case Accounts.update_user_features(scope, user, features) do
        {:ok, _updated_user} ->
          users = Accounts.list_household_users(scope)

          {:noreply,
           socket
           |> assign(users: users)
           |> put_flash(:info, "Updated access for #{user.username}.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Could not update member access.")}
      end
    else
      {:noreply, put_flash(socket, :error, "User not found.")}
    end
  end

  def handle_event("save_user_features", %{"user_id" => user_id}, socket) do
    handle_event("save_user_features", %{"user_id" => user_id, "features" => []}, socket)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-2xl font-semibold">Manage Users</h1>
          <p class="text-sm text-base-content/60 mt-1">Members of {@current_scope.household.name}</p>
        </div>
        <.button :if={not @show_form} phx-click="new_member" variant="primary">+ New Member</.button>
      </div>

      <div :if={@show_form} class="card bg-base-100 border border-base-200 shadow-sm mb-6">
        <div class="card-body p-4">
          <div class="flex items-center justify-between mb-4">
            <h2 class="font-semibold text-lg">New Member</h2>
            <.button phx-click="cancel_form" class="btn btn-ghost btn-sm btn-circle">
              <.icon name="hero-x-mark" class="size-4" />
            </.button>
          </div>
          <.form for={@new_member_form} phx-change="validate_member" phx-submit="create_member">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <.input field={@new_member_form[:username]} label="Username" />
              <.input field={@new_member_form[:email]} type="email" label="Email" />
              <.input field={@new_member_form[:password]} type="password" label="Password" />
              <.input
                field={@new_member_form[:password_confirmation]}
                type="password"
                label="Confirm Password"
              />
              <div>
                <label class="label">
                  <span class="label-text font-medium">Role</span>
                </label>
                <select name="user[role]" class="select select-bordered w-full">
                  <option value="adult">Adult</option>
                  <option value="admin">Admin</option>
                  <option value="child">Child</option>
                </select>
              </div>
              <div>
                <p class="label-text font-medium mb-2">Feature Access</p>
                <details class="dropdown">
                  <summary class="btn btn-sm btn-outline">
                    Select feature access ▾
                  </summary>
                  <div class="dropdown-content z-[1] bg-base-100 border border-base-200 rounded-box shadow-lg p-3 mt-1 w-52">
                    <% enabled = Enum.filter(@all_features, fn k -> Map.get(@household.features || %{}, k, false) end) %>
                    <p :if={enabled == []} class="text-xs text-base-content/50">
                      No features enabled for this household.
                    </p>
                    <div :if={enabled != []} class="flex flex-col gap-2">
                      <%= for key <- enabled do %>
                        <label class="flex items-center gap-2 cursor-pointer">
                          <input
                            type="checkbox"
                            name="user[features][]"
                            value={key}
                            checked
                            class="checkbox checkbox-sm"
                          />
                          <span class="text-sm">{@feature_labels[key]}</span>
                        </label>
                      <% end %>
                    </div>
                  </div>
                </details>
                <p class="text-xs text-base-content/50 mt-1">
                  Only household-enabled features shown. All selected by default.
                </p>
              </div>
            </div>
            <div class="mt-4 flex justify-end gap-2">
              <.button type="button" phx-click="cancel_form" class="btn btn-ghost">Cancel</.button>
              <.button type="submit" variant="primary">Create Member</.button>
            </div>
          </.form>
        </div>
      </div>

      <div>
        <table class="table">
          <thead>
            <tr>
              <th>Username</th>
              <th>Email</th>
              <th>Role</th>
              <th>Feature Access</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={user <- @users} class="hover">
              <td class="font-medium">{user.username}</td>
              <td>{user.email}</td>
              <td>
                <form phx-change="update_role" phx-value-user-id={user.id}>
                  <select
                    name="role"
                    class="select select-sm select-bordered"
                    disabled={user.id == @current_scope.user.id}
                  >
                    <option value="admin" selected={user.role == "admin"}>Admin</option>
                    <option value="adult" selected={user.role == "adult"}>Adult</option>
                    <option value="child" selected={user.role == "child"}>Child</option>
                  </select>
                </form>
              </td>
              <td>
                <form id={"user-features-#{user.id}"} phx-submit="save_user_features" class="items-start">
                  <input type="hidden" name="user_id" value={user.id} />
                  <details class="dropdown">
                    <summary class="btn btn-sm btn-outline">
                      {user_feature_count(user, @household, @all_features)} / {household_feature_count(@household, @all_features)} features ▾
                    </summary>
                    <div class="dropdown-content z-[1] bg-base-100 border border-base-200 rounded-box shadow-lg p-3 mt-1 w-52">
                      <div class="flex flex-col gap-2">
                        <%= for key <- @all_features, Map.get(@household.features || %{}, key, false) do %>
                          <label class="flex items-center gap-2 cursor-pointer">
                            <input
                              type="checkbox"
                              name="features[]"
                              value={key}
                              checked={Map.get(user.features || %{}, key, true)}
                              class="checkbox checkbox-sm"
                            />
                            <span class="text-sm">{@feature_labels[key]}</span>
                          </label>
                        <% end %>
                      </div>
                      <div class="mt-3 pt-2 border-t border-base-200">
                        <button type="submit" class="btn btn-primary btn-sm w-full">Apply</button>
                      </div>
                    </div>
                  </details>
                </form>
              </td>
              <td class="text-right">
                <div class="flex gap-1 justify-end">
                  <button
                    :if={user.id != @current_scope.user.id}
                    type="button"
                    phx-click="delete_user"
                    phx-value-user-id={user.id}
                    data-confirm="Are you sure you want to remove this user?"
                    class="btn btn-error btn-outline btn-xs"
                  >
                    Remove
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp blank_new_member_form do
    %User{} |> User.admin_create_changeset(%{}) |> to_form(as: "user")
  end

  defp user_feature_count(user, household, all_features) do
    hf = household.features || %{}
    uf = user.features || %{}
    Enum.count(all_features, fn k -> Map.get(hf, k, false) and Map.get(uf, k, true) end)
  end

  defp household_feature_count(household, all_features) do
    hf = household.features || %{}
    Enum.count(all_features, fn k -> Map.get(hf, k, false) end)
  end
end
