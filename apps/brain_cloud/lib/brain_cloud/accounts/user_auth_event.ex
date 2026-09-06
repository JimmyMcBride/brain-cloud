defmodule BrainCloud.Accounts.UserAuthEvent do
  use Ecto.Schema

  import Ecto.Changeset

  @actions ~w(email.verify session.create session.reissue organization.select session.logout)
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "user_auth_events" do
    field :action, :string
    field :metadata, :map, default: %{}

    belongs_to :user, BrainCloud.Accounts.User
    belongs_to :browser_session, BrainCloud.Accounts.BrowserSession

    timestamps(updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:user_id, :browser_session_id, :action, :metadata])
    |> validate_required([:user_id, :browser_session_id, :action, :metadata])
    |> validate_inclusion(:action, @actions)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:browser_session_id, name: :user_auth_events_session_user_fkey)
    |> check_constraint(:action, name: :user_auth_events_action_check)
  end
end
