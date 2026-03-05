defmodule Hearth.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Hearth.Repo,
      {DNSCluster, query: Application.get_env(:hearth, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Hearth.PubSub}
      # Start a worker by calling: Hearth.Worker.start_link(arg)
      # {Hearth.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Hearth.Supervisor)
  end
end
