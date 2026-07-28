defmodule BrainCloud.Accounts.Organization do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "organizations" do
    field :name, :string
    field :slug, :string

    has_many :memberships, BrainCloud.Accounts.OrganizationMembership

    timestamps()
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :slug])
    |> update_change(:name, &String.trim/1)
    |> update_change(:slug, &normalize_slug/1)
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 1, max: 120)
    |> validate_length(:slug, min: 1, max: 63)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> unique_constraint(:slug)
  end

  def normalize_slug(slug) when is_binary(slug) do
    slug
    |> String.trim()
    |> String.downcase()
  end
end
