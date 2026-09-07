defmodule BrainCloudWeb.BrowserInvitationControllerTest do
  use BrainCloudWeb.ConnCase, async: false
  alias BrainCloud.Accounts
  alias BrainCloud.Repo
  alias BrainCloud.Accounts.{OrganizationInvitation, ApiToken}
  import Ecto.Query

  defmodule FailedDelivery do
    use Swoosh.Adapter
    def deliver(_email, _config), do: {:error, :relay_unavailable}
  end

  test "SMTP failure leaves an unusable pending generation and safe feedback", %{
    conn: conn,
    identity: owner
  } do
    config = Application.fetch_env!(:brain_cloud_web, BrainCloudWeb.Mailer)
    Application.put_env(:brain_cloud_web, BrainCloudWeb.Mailer, adapter: FailedDelivery)
    on_exit(fn -> Application.put_env(:brain_cloud_web, BrainCloudWeb.Mailer, config) end)
    conn = init_test_session(conn, %{"browser_session_token" => session(owner)})

    response =
      post(conn, ~p"/organization/invitations",
        invitation: %{email: "failed@example.test", display_name: "Recipient"}
      )

    assert redirected_to(response, 303) == "/organization/invitations"
    assert Phoenix.Flash.get(response.assigns.flash, :info) =~ "could not be confirmed"
    refute inspect(response.assigns.flash) =~ "relay_unavailable"
    invitation = Repo.get_by!(OrganizationInvitation, email: "failed@example.test")
    assert invitation.delivery_state == "failed"
    assert OrganizationInvitation.status(invitation) == "pending"
  end

  test "invitation confirmation requires CSRF", %{identity: owner} do
    {:ok, invitation, raw} = invitation(owner)

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      Plug.Test.conn(:post, "/invitations/accept", %{"invitation" => %{"token" => raw}})
      |> BrainCloudWeb.Endpoint.call([])
    end

    assert Repo.get!(OrganizationInvitation, invitation.id).accepted_at == nil
  end

  test "owner sends mail, gets safe status, and resend cooldown is enforced", %{
    conn: conn,
    identity: owner
  } do
    conn = init_test_session(conn, %{"browser_session_token" => session(owner)})

    response =
      post(conn, ~p"/organization/invitations",
        invitation: %{email: "web-invite@example.test", display_name: "Recipient"}
      )

    assert redirected_to(response, 303) == "/organization/invitations"
    invitation = Repo.get_by!(OrganizationInvitation, email: "web-invite@example.test")
    assert invitation.delivery_state == "sent"
    panel = get(recycle(response), ~p"/organization/invitations")
    assert html_response(panel, 200) =~ "web-invite@example.test"
    assert get_resp_header(panel, "cache-control") == ["no-store"]
    limited = post(recycle(panel), ~p"/organization/invitations/#{invitation.id}/send")
    assert html_response(limited, 429) =~ "Too many"
    assert [_] = get_resp_header(limited, "retry-after")
    owner.membership |> Ecto.Changeset.change(role: "member") |> Repo.update!()
    assert html_response(get(recycle(limited), ~p"/organization/invitations"), 404)
  end

  test "scanner-safe landing, explicit preview and credential-free join", %{
    conn: conn,
    identity: owner
  } do
    {:ok, invitation, token} = invitation(owner)
    before_tokens = Repo.aggregate(ApiToken, :count)
    landing = get(conn, ~p"/invitations/accept")
    assert html_response(landing, 200) =~ "Review invitation"
    assert Repo.get!(OrganizationInvitation, invitation.id).accepted_at == nil
    assert get_resp_header(landing, "referrer-policy") == ["no-referrer"]
    preview = post(recycle(landing), ~p"/invitations/preview", invitation: %{token: token})
    assert html_response(preview, 200) =~ owner.organization.name
    assert Repo.get!(OrganizationInvitation, invitation.id).accepted_at == nil
    joined = post(recycle(preview), ~p"/invitations/accept", invitation: %{token: token})
    assert redirected_to(joined, 303) == "/sign-in"
    assert get_session(joined, "browser_session_token") == nil
    assert Repo.aggregate(ApiToken, :count) == before_tokens
    assert Repo.get!(OrganizationInvitation, invitation.id).accepted_at

    assert html_response(
             post(recycle(joined), ~p"/invitations/accept", invitation: %{token: token}),
             404
           )
  end

  test "mismatched identity must sign out and bearer auth cannot manage browser invites", %{
    conn: conn,
    identity: owner
  } do
    {:ok, invitation, token} = invitation(owner)
    browser = init_test_session(conn, %{"browser_session_token" => session(owner)})
    response = post(browser, ~p"/invitations/accept", invitation: %{token: token})
    assert html_response(response, 409) =~ "different email"
    assert Repo.get!(OrganizationInvitation, invitation.id).accepted_at == nil
    api = authenticate(build_conn(), owner)
    assert redirected_to(get(api, ~p"/organization/invitations")) == "/sign-in"

    assert Repo.aggregate(
             from(i in OrganizationInvitation, where: not is_nil(i.accepted_at)),
             :count
           ) == 0
  end

  defp invitation(owner) do
    Accounts.create_organization_invitation(owner.auth_context, %{
      email: "recipient@example.test",
      display_name: "Recipient",
      scopes: ["memory.read"],
      expires_at: DateTime.add(DateTime.utc_now(), 3600)
    })
  end

  defp session(owner) do
    {:ok, {:deliver, challenge, raw, _}} = Accounts.request_browser_login(owner.user.email)
    {:ok, _} = Accounts.mark_browser_login_sent(challenge.id)
    {:ok, _, token} = Accounts.confirm_browser_login(raw)
    token
  end
end
