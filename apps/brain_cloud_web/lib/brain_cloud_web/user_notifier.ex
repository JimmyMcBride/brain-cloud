defmodule BrainCloudWeb.UserNotifier do
  @moduledoc false

  import Swoosh.Email

  alias BrainCloud.Accounts.User
  alias BrainCloudWeb.Mailer

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
