defmodule BrainCloud.Accounts.OrganizationMembership do
  use Ecto.Schema

  import Ecto.Changeset

  @roles ~w(owner member)
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "organization_memberships" do
    field :role, :string
    field :deactivated_at, :utc_datetime_usec

    belongs_to :user, BrainCloud.Accounts.User
    belongs_to :organization, BrainCloud.Accounts.Organization
    has_many :api_tokens, BrainCloud.Accounts.ApiToken, foreign_key: :membership_id

    has_many :project_access_grants, BrainCloud.Projects.ProjectAccessGrant,
      foreign_key: :organization_membership_id

    timestamps()
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :organization_id, :role, :deactivated_at])
    |> validate_required([:user_id, :organization_id, :role])
    |> validate_inclusion(:role, @roles)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:organization_id)
    |> unique_constraint([:user_id, :organization_id])
    |> check_constraint(:role, name: :organization_memberships_role_check)
  end
end
