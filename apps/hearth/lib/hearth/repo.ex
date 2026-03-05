defmodule Hearth.Repo do
  use Ecto.Repo,
    otp_app: :hearth,
    adapter: Ecto.Adapters.Postgres
end
