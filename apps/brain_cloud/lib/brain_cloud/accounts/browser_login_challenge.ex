defmodule BrainCloud.Accounts.BrowserLoginChallenge do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "browser_login_challenges" do
    field :public_id, :string
    field :token_digest, :binary
    field :sent_at, :utc_datetime_usec
    field :consumed_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    belongs_to :user, BrainCloud.Accounts.User

    timestamps()
  end

  def changeset(challenge, attrs) do
    challenge
    |> cast(attrs, [:user_id, :public_id, :token_digest, :sent_at, :consumed_at, :revoked_at])
    |> validate_required([:user_id, :public_id, :token_digest])
    |> validate_length(:public_id, is: 32)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:public_id)
    |> unique_constraint(:token_digest)
    |> unique_constraint(:user_id, name: :browser_login_challenges_active_user_index)
    |> check_constraint(:public_id, name: :browser_login_challenges_public_id_length_check)
    |> check_constraint(:token_digest, name: :browser_login_challenges_digest_length_check)
    |> check_constraint(:consumed_at, name: :browser_login_challenges_terminal_state_check)
  end
end
