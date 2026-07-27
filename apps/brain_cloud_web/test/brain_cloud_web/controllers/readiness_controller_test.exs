defmodule BrainCloudWeb.ReadinessControllerTest do
  use BrainCloudWeb.ConnCase

  defmodule Ready do
    def ready?, do: true
  end

  defmodule NotReady do
    def ready?, do: false
  end

  setup do
    original = Application.get_env(:brain_cloud_web, :readiness_checker)

    on_exit(fn ->
      if original do
        Application.put_env(:brain_cloud_web, :readiness_checker, original)
      else
        Application.delete_env(:brain_cloud_web, :readiness_checker)
      end
    end)
  end

  test "returns ready when PostgreSQL responds", %{conn: conn} do
    Application.put_env(:brain_cloud_web, :readiness_checker, Ready)

    conn = get(conn, ~p"/readyz")

    assert json_response(conn, 200) == %{"status" => "ready"}
  end

  test "returns service unavailable when PostgreSQL is unavailable", %{conn: conn} do
    Application.put_env(:brain_cloud_web, :readiness_checker, NotReady)

    conn = get(conn, ~p"/readyz")

    assert json_response(conn, 503) == %{"status" => "not_ready"}
  end
end
