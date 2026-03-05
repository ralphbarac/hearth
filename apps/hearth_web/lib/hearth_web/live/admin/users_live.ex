defmodule HearthWeb.Admin.UsersLive do
  use HearthWeb, :live_view

  alias Hearth.Accounts

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_household_users(socket.assigns.current_scope)
    {:ok, assign(socket, page_title: "Manage Users", users: users)}
  end

  @impl true
  def handle_event("update_role", %{"user-id" => user_id, "role" => role}, socket) do
    user = Accounts.get_user!(user_id)

    case Accounts.update_user_role(user, role) do
      {:ok, _user} ->
        users = Accounts.list_household_users(socket.assigns.current_scope)
        {:noreply, assign(socket, users: users)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update role.")}
    end
  end

  def handle_event("delete_user", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <.header>
        Manage Users
        <:subtitle>
          Manage members of {@current_scope.household.name}
        </:subtitle>
      </.header>

      <div class="mt-6 overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Username</th>
              <th>Email</th>
              <th>Role</th>
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
              <td class="text-right">
                <button
                  :if={user.id != @current_scope.user.id}
                  phx-click="delete_user"
                  phx-value-user-id={user.id}
                  data-confirm="Are you sure you want to remove this user?"
                  class="btn btn-error btn-outline btn-sm"
                >
                  Remove
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
