defmodule BrainCloud.ReadinessTest do
  use BrainCloud.DataCase

  test "reports ready when PostgreSQL responds" do
    assert BrainCloud.Readiness.ready?()
  end

  test "reports not ready when the database query fails" do
    refute BrainCloud.Readiness.ready?(fn -> {:error, :database_unavailable} end)
  end

  test "reports not ready when the database query exits" do
    refute BrainCloud.Readiness.ready?(fn -> exit(:database_unavailable) end)
  end
end
