defmodule BrainCloud.Accounts.User do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "users" do
    field :email, :string
    field :display_name, :string
    field :email_verified_at, :utc_datetime_usec

    has_many :memberships, BrainCloud.Accounts.OrganizationMembership
    has_many :browser_login_challenges, BrainCloud.Accounts.BrowserLoginChallenge
    has_many :browser_sessions, BrainCloud.Accounts.BrowserSession

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :display_name, :email_verified_at])
    |> update_change(:email, &normalize_email/1)
    |> update_change(:display_name, &String.trim/1)
    |> validate_required([:email, :display_name])
    |> validate_length(:email, max: 254)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+$/)
    |> validate_length(:display_name, min: 1, max: 120)
    |> unique_constraint(:email)
  end

  def normalize_email(email) when is_binary(email) do
    email
    |> String.trim()
    |> String.downcase()
  end
end
