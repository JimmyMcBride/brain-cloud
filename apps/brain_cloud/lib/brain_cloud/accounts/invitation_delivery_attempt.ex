defmodule BrainCloud.Accounts.InvitationDeliveryAttempt do
  @moduledoc false
  use Ecto.Schema
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "invitation_delivery_attempts" do
    field :organization_id, :binary_id
    field :invitation_id, :binary_id
    field :requested_by_user_id, :binary_id
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
