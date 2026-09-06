defmodule BrainCloud.Accounts.BrowserSession do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "browser_sessions" do
    field :public_id, :string
    field :token_digest, :binary
    field :authenticated_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    belongs_to :user, BrainCloud.Accounts.User
    belongs_to :selected_membership, BrainCloud.Accounts.OrganizationMembership

    has_many :auth_events, BrainCloud.Accounts.UserAuthEvent

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :user_id,
      :selected_membership_id,
      :public_id,
      :token_digest,
      :authenticated_at,
      :expires_at,
      :revoked_at
    ])
    |> validate_required([:user_id, :public_id, :token_digest, :authenticated_at, :expires_at])
    |> validate_length(:public_id, is: 32)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:selected_membership_id,
      name: :browser_sessions_selected_membership_user_fkey
    )
    |> unique_constraint(:public_id)
    |> unique_constraint(:token_digest)
    |> check_constraint(:public_id, name: :browser_sessions_public_id_length_check)
    |> check_constraint(:token_digest, name: :browser_sessions_digest_length_check)
    |> check_constraint(:expires_at, name: :browser_sessions_expiry_check)
  end
end
