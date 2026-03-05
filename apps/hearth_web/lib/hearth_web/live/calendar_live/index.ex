defmodule HearthWeb.CalendarLive.Index do
  use HearthWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Calendar")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 md:p-8">
      <.header>Calendar</.header>
      <p class="mt-4 text-secondary">Coming soon.</p>
    </div>
    """
  end
end
