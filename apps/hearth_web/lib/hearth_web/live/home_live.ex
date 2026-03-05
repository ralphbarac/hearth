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
      <h1 class="text-2xl font-semibold text-base-content">
        Welcome, {@current_scope.user.username || @current_scope.user.email}!
      </h1>
      <p class="mt-2 text-secondary">Your household dashboard will appear here.</p>
    </div>
    """
  end
end
