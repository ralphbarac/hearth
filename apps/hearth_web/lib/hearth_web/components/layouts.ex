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

  attr :active_nav, :atom, default: nil, doc: "the active nav section atom"

  slot :inner_block, required: true

  def sidebar_layout(assigns) do
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
            <div class="flex-1 flex items-center gap-2 ml-1">
              <.icon name="hero-fire" class="size-5 text-primary" />
              <span class="text-lg font-semibold text-primary">Hearth</span>
            </div>
            <div class="flex-none">
              <div class="avatar placeholder">
                <div class="bg-primary text-primary-content w-8 rounded-full">
                  <span class="text-xs">
                    {String.first(@current_scope.user.username || @current_scope.user.email)
                    |> String.upcase()}
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
                <.icon name="hero-fire" class="size-6 text-primary" />
                <span class="text-xl font-semibold text-primary">Hearth</span>
              </a>
            </div>

            <%!-- Nav items --%>
            <nav class="flex-1 p-2 space-y-0.5 sidebar-scroll overflow-y-auto">
              <.nav_link
                href={~p"/dashboard"}
                icon="hero-squares-2x2"
                label="Dashboard"
                active={@active_nav == :dashboard}
              />

              <%!-- PLANNING section --%>
              <p
                :if={
                  feature_enabled?(@current_scope, "calendar") or
                    (feature_enabled?(@current_scope, "calendar") and
                       feature_enabled?(@current_scope, "recipes"))
                }
                class="text-[10px] font-semibold tracking-widest text-base-content/40 uppercase px-3 pt-4 pb-1 mt-1"
              >
                Planning
              </p>
              <.nav_link
                :if={feature_enabled?(@current_scope, "calendar")}
                href={~p"/calendar"}
                icon="hero-calendar-days"
                label="Calendar"
                active={@active_nav == :calendar}
              />
              <.nav_link
                :if={
                  feature_enabled?(@current_scope, "calendar") and
                    feature_enabled?(@current_scope, "recipes")
                }
                href={~p"/meal-plan"}
                icon="hero-clipboard-document-list"
                label="Meal Planner"
                active={@active_nav == :meal_plan}
              />

              <%!-- FINANCE section --%>
              <p
                :if={feature_enabled?(@current_scope, "budget")}
                class="text-[10px] font-semibold tracking-widest text-base-content/40 uppercase px-3 pt-4 pb-1 mt-1"
              >
                Finance
              </p>
              <.nav_link
                :if={feature_enabled?(@current_scope, "budget")}
                href={~p"/budget"}
                icon="hero-banknotes"
                label="Budget"
                active={@active_nav == :budget}
              />
              <.nav_link
                :if={feature_enabled?(@current_scope, "budget")}
                href={~p"/bills"}
                icon="hero-document-text"
                label="Recurring Bills"
                active={@active_nav == :bills}
              />

              <%!-- HOME LIFE section --%>
              <p
                :if={
                  feature_enabled?(@current_scope, "grocery") or
                    feature_enabled?(@current_scope, "inventory") or
                    feature_enabled?(@current_scope, "recipes") or
                    feature_enabled?(@current_scope, "chores") or
                    feature_enabled?(@current_scope, "maintenance")
                }
                class="text-[10px] font-semibold tracking-widest text-base-content/40 uppercase px-3 pt-4 pb-1 mt-1"
              >
                Home Life
              </p>
              <.nav_link
                :if={feature_enabled?(@current_scope, "grocery")}
                href={~p"/grocery"}
                icon="hero-shopping-cart"
                label="Grocery Lists"
                active={@active_nav == :grocery}
              />
              <.nav_link
                :if={feature_enabled?(@current_scope, "recipes")}
                href={~p"/recipes"}
                icon="hero-book-open"
                label="Recipes"
                active={@active_nav == :recipes}
              />
              <.nav_link
                :if={feature_enabled?(@current_scope, "inventory")}
                href={~p"/inventory"}
                icon="hero-archive-box"
                label="Inventory"
                active={@active_nav == :inventory}
              />
              <.nav_link
                :if={feature_enabled?(@current_scope, "chores")}
                href={~p"/chores"}
                icon="hero-check-circle"
                label="Chores"
                active={@active_nav == :chores}
              />
              <.nav_link
                :if={feature_enabled?(@current_scope, "maintenance")}
                href={~p"/maintenance"}
                icon="hero-wrench-screwdriver"
                label="Maintenance"
                active={@active_nav == :maintenance}
              />

              <%!-- RECORDS section --%>
              <p
                :if={
                  feature_enabled?(@current_scope, "contacts") or
                    feature_enabled?(@current_scope, "documents")
                }
                class="text-[10px] font-semibold tracking-widest text-base-content/40 uppercase px-3 pt-4 pb-1 mt-1"
              >
                Records
              </p>
              <.nav_link
                :if={feature_enabled?(@current_scope, "contacts")}
                href={~p"/contacts"}
                icon="hero-user-group"
                label="Contacts"
                active={@active_nav == :contacts}
              />
              <.nav_link
                :if={feature_enabled?(@current_scope, "documents")}
                href={~p"/documents"}
                icon="hero-folder"
                label="Documents"
                active={@active_nav == :documents}
              />

              <%= if @current_scope.user.role == "admin" do %>
                <p class="px-3 pt-4 pb-1 text-xs font-semibold tracking-widest text-base-content/40 uppercase">
                  Admin
                </p>
                <.nav_link
                  href={~p"/admin/users"}
                  icon="hero-users"
                  label="Users"
                  active={@active_nav == :admin_users}
                />
                <.nav_link
                  href={~p"/admin/household"}
                  icon="hero-cog-6-tooth"
                  label="Settings"
                  active={@active_nav == :admin_household}
                />
                <.nav_link
                  href={~p"/admin/features"}
                  icon="hero-puzzle-piece"
                  label="Features"
                  active={@active_nav == :admin_features}
                />
                <.nav_link
                  href={~p"/admin/categories"}
                  icon="hero-tag"
                  label="Categories"
                  active={@active_nav == :admin_categories}
                />
              <% end %>
            </nav>

            <%!-- User info at bottom --%>
            <div class="p-4 border-t border-base-300">
              <div class="flex items-center gap-2 mb-3">
                <div class="avatar placeholder">
                  <div class="bg-primary text-primary-content w-8 rounded-full">
                    <span class="text-xs">
                      {String.first(@current_scope.user.username || @current_scope.user.email)
                      |> String.upcase()}
                    </span>
                  </div>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium truncate">{@current_scope.user.username}</p>
                  <p class="text-xs text-base-content/50 truncate">{@current_scope.user.email}</p>
                </div>
              </div>
              <div class="flex gap-1">
                <.link
                  href={~p"/users/settings"}
                  class="flex items-center gap-1.5 text-xs text-base-content/60 hover:text-base-content px-2 py-1.5 rounded-lg hover:bg-base-300 flex-1 transition-colors"
                >
                  <.icon name="hero-cog-6-tooth" class="size-3.5" /> Account
                </.link>
                <.link
                  href={~p"/users/log-out"}
                  method="delete"
                  class="flex items-center gap-1.5 text-xs text-base-content/60 hover:text-base-content px-2 py-1.5 rounded-lg hover:bg-base-300 flex-1 transition-colors"
                >
                  <.icon name="hero-arrow-right-on-rectangle" class="size-3.5" /> Log out
                </.link>
              </div>
            </div>
          </aside>
        </div>
      </div>
    <% else %>
      <main class="min-h-screen bg-base-200 flex items-center justify-center px-4 py-12">
        {render_slot(@inner_block)}
      </main>
    <% end %>

    <.flash_group flash={@flash} />
    """
  end

  defp feature_enabled?(scope, feature) do
    Hearth.Accounts.feature_enabled?(scope, feature)
  end

  defp nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium border-l-2 transition-colors",
        if(@active,
          do: "bg-primary/10 text-primary border-primary",
          else: "text-base-content hover:bg-base-300 border-transparent"
        )
      ]}
    >
      <.icon name={@icon} class="size-5 shrink-0" />
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
