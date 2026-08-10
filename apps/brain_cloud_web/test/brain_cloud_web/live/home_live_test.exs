defmodule BrainCloudWeb.HomeLiveTest do
  use BrainCloudWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "shows the honest bootstrap surface", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Brain Cloud"
    assert html =~ "Phase 2F API"
    assert html =~ "human and agent credentials"
    assert html =~ "direct, team, and agent project-access administration"
    assert html =~ "organization membership"
    assert html =~ "organization-scoped durable"
    assert html =~ "no product UI"
    refute html =~ "Peace of mind from prototype to production"
  end
end
