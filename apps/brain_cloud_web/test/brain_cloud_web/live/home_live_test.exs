defmodule BrainCloudWeb.HomeLiveTest do
  use BrainCloudWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias BrainCloud.Accounts
  alias BrainCloud.Repo

  test "shows the honest signed-out foundation", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Brain Cloud"
    assert html =~ "Phase 2H foundation"
    assert html =~ ~s(id="signed-out")
    assert html =~ "closed to existing users"
    assert html =~ "not a project or administration dashboard"
    refute html =~ ~s(id="signed-in")
  end

  test "shows the selected identity shell for one membership", %{conn: conn, identity: identity} do
    {_scope, session_token} = browser_session(identity.user.email)

    {:ok, _view, html} =
      conn
      |> init_test_session(%{"browser_session_token" => session_token})
      |> live(~p"/")

    assert html =~ ~s(id="signed-in")
    assert html =~ identity.user.display_name
    assert html =~ identity.organization.name
    assert html =~ "Current role: owner"
    assert html =~ "product workflows remain API-only"
    refute html =~ ~s(id="organization-chooser")
  end

  test "shows the chooser, permits switching, and rejects another user's membership", %{
    conn: conn,
    identity: identity
  } do
    other = BrainCloud.DataCase.identity_fixture()

    assert {:ok, second_membership} =
             Accounts.create_organization_membership(other.auth_context, %{
               email: identity.user.email,
               display_name: identity.user.display_name,
               role: "member"
             })

    {_scope, session_token} = browser_session(identity.user.email)
    signed_in_conn = init_test_session(conn, %{"browser_session_token" => session_token})
    {:ok, _view, html} = live(signed_in_conn, ~p"/")

    assert html =~ ~s(id="organization-chooser")
    assert html =~ identity.organization.name
    assert html =~ other.organization.name

    selected_conn =
      signed_in_conn
      |> post(~p"/organizations/select", %{"membership_id" => second_membership.id})

    assert redirected_to(selected_conn) == "/"
    assert {:ok, selected_scope, nil} = Accounts.authenticate_browser_session(session_token)
    assert selected_scope.organization.id == other.organization.id

    stranger = BrainCloud.DataCase.identity_fixture()

    rejected_conn =
      signed_in_conn
      |> recycle()
      |> post(~p"/organizations/select", %{"membership_id" => stranger.membership.id})

    assert redirected_to(rejected_conn) == "/"

    assert Phoenix.Flash.get(rejected_conn.assigns.flash, :error) ==
             "That organization is not available."
  end

  test "a reconnect refreshes role and selected membership state", %{
    conn: conn,
    identity: identity
  } do
    other = BrainCloud.DataCase.identity_fixture()

    assert {:ok, membership} =
             Accounts.create_organization_membership(other.auth_context, %{
               email: identity.user.email,
               display_name: identity.user.display_name,
               role: "member"
             })

    {_scope, session_token} = browser_session(identity.user.email)
    assert {:ok, _scope} = Accounts.select_browser_membership(session_token, membership.id)
    signed_in_conn = init_test_session(conn, %{"browser_session_token" => session_token})

    {:ok, _view, html} = live(signed_in_conn, ~p"/")
    assert html =~ "Current role: member"

    assert {:ok, _membership} =
             Accounts.update_organization_membership_role(
               other.auth_context,
               membership.id,
               "owner"
             )

    {:ok, _view, html} = live(signed_in_conn, ~p"/")
    assert html =~ "Current role: owner"

    Repo.update!(
      Ecto.Changeset.change(membership, deactivated_at: DateTime.utc_now(:microsecond))
    )

    {:ok, _view, html} = live(signed_in_conn, ~p"/")
    assert html =~ ~s(id="organization-chooser")
    refute html =~ ~s(id="signed-in")
  end

  defp browser_session(email) do
    assert {:ok, {:deliver, challenge, raw_login_token, _user}} =
             Accounts.request_browser_login(email)

    assert {:ok, _challenge} = Accounts.mark_browser_login_sent(challenge.id)
    assert {:ok, scope, session_token} = Accounts.confirm_browser_login(raw_login_token)
    {scope, session_token}
  end
end
