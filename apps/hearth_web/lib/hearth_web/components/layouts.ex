defmodule HearthWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use HearthWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders the app layout with sidebar navigation.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current scope"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%= if @current_scope do %>
      <div class="drawer md:drawer-open">
        <input id="sidebar-drawer" type="checkbox" class="drawer-toggle" />

        <div class="drawer-content flex flex-col min-h-screen">
          <%!-- Mobile top bar --%>
          <header class="navbar bg-base-200 border-b border-base-300 md:hidden">
            <div class="flex-none">
              <label for="sidebar-drawer" class="btn btn-ghost btn-square" aria-label="Open menu">
                <.icon name="hero-bars-3" class="size-5" />
              </label>
            </div>
            <div class="flex-1">
              <span class="text-lg font-semibold text-primary">Hearth</span>
            </div>
            <div class="flex-none">
              <div class="avatar placeholder">
                <div class="bg-primary text-primary-content w-8 rounded-full">
                  <span class="text-xs">
                    {String.first(@current_scope.user.username || @current_scope.user.email) |> String.upcase()}
                  </span>
                </div>
              </div>
            </div>
          </header>

          <main class="flex-1">
            {render_slot(@inner_block)}
          </main>
        </div>

        <%!-- Sidebar drawer --%>
        <div class="drawer-side z-40">
          <label for="sidebar-drawer" class="drawer-overlay" aria-label="Close menu"></label>
          <aside class="bg-base-200 border-r border-base-300 w-60 min-h-screen flex flex-col">
            <%!-- Logo --%>
            <div class="p-4 border-b border-base-300">
              <a href={~p"/dashboard"} class="flex items-center gap-2">
                <.icon name="hero-home-solid" class="size-6 text-primary" />
                <span class="text-xl font-semibold text-primary">Hearth</span>
              </a>
            </div>

            <%!-- Nav items --%>
            <nav class="flex-1 p-2">
              <ul class="menu gap-1">
                <li>
                  <.nav_link href={~p"/dashboard"} icon="hero-squares-2x2" label="Dashboard" />
                </li>
                <li>
                  <.nav_link href={~p"/calendar"} icon="hero-calendar-days" label="Calendar" />
                </li>
                <li>
                  <.nav_link href={~p"/budget"} icon="hero-banknotes" label="Budget" />
                </li>
                <li>
                  <.nav_link href={~p"/grocery"} icon="hero-shopping-cart" label="Grocery Lists" />
                </li>
              </ul>

              <%= if @current_scope.user.role == "admin" do %>
                <div class="divider my-1"></div>
                <ul class="menu gap-1">
                  <li>
                    <.nav_link href={~p"/admin/users"} icon="hero-users" label="Users" />
                  </li>
                  <li>
                    <.nav_link href={~p"/admin/household"} icon="hero-cog-6-tooth" label="Settings" />
                  </li>
                </ul>
              <% end %>
            </nav>

            <%!-- User info at bottom --%>
            <div class="p-4 border-t border-base-300">
              <div class="flex items-center gap-2">
                <div class="avatar placeholder">
                  <div class="bg-primary text-primary-content w-8 rounded-full">
                    <span class="text-xs">
                      {String.first(@current_scope.user.username || @current_scope.user.email) |> String.upcase()}
                    </span>
                  </div>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium truncate">{@current_scope.user.username}</p>
                  <p class="text-xs text-secondary truncate">{@current_scope.user.email}</p>
                </div>
              </div>
              <div class="mt-2 flex gap-2">
                <.link href={~p"/users/settings"} class="btn btn-ghost btn-xs flex-1">
                  Settings
                </.link>
                <.link href={~p"/users/log-out"} method="delete" class="btn btn-ghost btn-xs flex-1">
                  Log out
                </.link>
              </div>
            </div>
          </aside>
        </div>
      </div>
    <% else %>
      <main class="min-h-screen">
        {render_slot(@inner_block)}
      </main>
    <% end %>

    <.flash_group flash={@flash} />
    """
  end

  defp nav_link(assigns) do
    ~H"""
    <a href={@href} class="flex items-center gap-3">
      <.icon name={@icon} class="size-5" />
      <span>{@label}</span>
    </a>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
