defmodule BrainCloud.Repo do
  use Ecto.Repo,
    otp_app: :brain_cloud,
    adapter: Ecto.Adapters.Postgres
end
