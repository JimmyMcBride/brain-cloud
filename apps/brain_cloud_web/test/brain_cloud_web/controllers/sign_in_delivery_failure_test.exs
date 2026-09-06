defmodule BrainCloudWeb.SignInDeliveryFailureTest do
  use BrainCloudWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Swoosh.TestAssertions

  alias BrainCloud.Accounts.BrowserLoginChallenge
  alias BrainCloud.Repo

  defmodule FailingAdapter do
    use Swoosh.Adapter

    @impl true
    def deliver(_email, _config), do: raise("relay unavailable")
  end

  setup do
    original = Application.fetch_env!(:brain_cloud_web, BrainCloudWeb.Mailer)
    Application.put_env(:brain_cloud_web, BrainCloudWeb.Mailer, adapter: FailingAdapter)

    on_exit(fn -> Application.put_env(:brain_cloud_web, BrainCloudWeb.Mailer, original) end)
  end

  test "delivery failure is non-enumerating, invalidates the challenge, and logs no email", %{
    conn: conn,
    identity: identity
  } do
    log =
      capture_log(fn ->
        html =
          conn
          |> post(~p"/sign-in", %{"sign_in" => %{"email" => identity.user.email}})
          |> html_response(200)

        assert html =~ "If this email can sign in, a link is on its way."
      end)

    challenge = Repo.one!(BrowserLoginChallenge)
    refute is_nil(challenge.revoked_at)
    refute log =~ identity.user.email
    refute log =~ "bcl1_"
    assert log =~ "browser sign-in delivery failed"
    refute_email_sent()
  end
end
