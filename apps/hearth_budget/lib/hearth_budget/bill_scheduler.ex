defmodule HearthBudget.BillScheduler do
  use GenServer
  require Logger

  alias HearthBudget.Bills

  @interval_ms 24 * 60 * 60 * 1_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    send(self(), :process)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:process, state) do
    try do
      Bills.process_overdue_for_all_households()
    rescue
      e ->
        Logger.error(
          "BillScheduler error: #{Exception.message(e)}\n#{Exception.format_stacktrace()}"
        )
    end

    :timer.send_after(@interval_ms, self(), :process)
    {:noreply, state}
  end
end
