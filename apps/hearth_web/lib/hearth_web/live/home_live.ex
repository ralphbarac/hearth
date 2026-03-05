defmodule HearthWeb.HomeLive do
  use HearthWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <h1 class="text-2xl font-semibold">
        Welcome, {@current_scope.user.username}!
      </h1>
      <p class="mt-1 text-secondary text-sm">{@current_scope.household.name}</p>

      <div class="mt-6 grid gap-4 md:grid-cols-2">
        <%!-- Upcoming Events Widget --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-base">
              <.icon name="hero-calendar-days" class="size-5 text-info" /> Upcoming Events
            </h2>
            <p class="text-secondary text-sm">No events yet. Add your first one!</p>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/calendar"} class="btn btn-ghost btn-sm text-primary">
                View Calendar &rarr;
              </.link>
            </div>
          </div>
        </div>

        <%!-- Budget Widget --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-base">
              <.icon name="hero-banknotes" class="size-5 text-primary" /> Budget This Month
            </h2>
            <p class="text-secondary text-sm">No transactions yet. Start tracking!</p>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/budget"} class="btn btn-ghost btn-sm text-primary">
                View Budget &rarr;
              </.link>
            </div>
          </div>
        </div>

        <%!-- Grocery Widget --%>
        <div class="card bg-base-100 border border-base-300 shadow-sm md:col-span-2">
          <div class="card-body">
            <h2 class="card-title text-base">
              <.icon name="hero-shopping-cart" class="size-5 text-accent" /> Grocery Lists
            </h2>
            <p class="text-secondary text-sm">No lists yet. Create your first one!</p>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/grocery"} class="btn btn-ghost btn-sm text-primary">
                View Lists &rarr;
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
