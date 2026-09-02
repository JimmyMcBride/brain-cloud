defmodule BrainCloudWeb.HomeLiveTest do
  use BrainCloudWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "shows the honest bootstrap surface", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Brain Cloud"
    assert html =~ "Phase 2G API"
    assert html =~ "invitations with public one-time acceptance"
    assert html =~ "human and agent credentials"
    assert html =~ "direct, team, and agent project-access"
    assert html =~ "invitation delivery, interactive login"
    assert html =~ "organization-scoped durable"
    assert html =~ "product UI are not implemented"
    refute html =~ "Peace of mind from prototype to production"
  end
end
