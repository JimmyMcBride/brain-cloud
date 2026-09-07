defmodule BrainCloudWeb.UserNotifier do
  @moduledoc false

  import Swoosh.Email

  alias BrainCloud.Accounts.User
  alias BrainCloudWeb.Mailer

  def deliver_invitation(invitation, raw_token) do
    {name, address} = Application.fetch_env!(:brain_cloud_web, :mailer_from)
    base_url = Application.fetch_env!(:brain_cloud_web, :public_app_url)
    url = "#{base_url}/invitations/accept#token=#{URI.encode_www_form(raw_token)}"

    new()
    |> to({invitation.display_name, invitation.email})
    |> from({name, address})
    |> subject("Invitation to Brain Cloud")
    |> text_body(
      "You have been invited to join Brain Cloud as a member.\n\nOpen this link to review and explicitly join:\n\n#{url}\n\nExpires at #{DateTime.to_iso8601(invitation.expires_at)}. Joining does not sign you in; use email sign-in afterward. If unexpected, ignore this email."
    )
    |> Mailer.deliver()
  end

  def deliver_sign_in_link(%User{} = user, confirmation_url) do
    {from_name, from_address} = Application.fetch_env!(:brain_cloud_web, :mailer_from)

    new()
    |> to({user.display_name, user.email})
    |> from({from_name, from_address})
    |> subject("Sign in to Brain Cloud")
    |> text_body("""
    Sign in to Brain Cloud

    Open this link, then confirm sign-in in your browser:

    #{confirmation_url}

    This link expires in 15 minutes and can be used once. If you did not request it, ignore this message.
    """)
    |> Mailer.deliver()
  end

  def sign_in_url(raw_token) do
    base_url = Application.fetch_env!(:brain_cloud_web, :public_app_url)
    "#{base_url}/sign-in/confirm#token=#{URI.encode_www_form(raw_token)}"
  end
end
