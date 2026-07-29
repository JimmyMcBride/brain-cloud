alias BrainCloud.{Accounts, Memories, Projects, Repo}
alias BrainCloud.Accounts.{ApiToken, OrganizationMembership, User}
alias BrainCloud.Projects.ProjectAccessGrant

import Ecto.Query

legacy_manager =
  Repo.one!(
    from token in ApiToken,
      where: token.name == "Bootstrap owner" and is_nil(token.revoked_at)
  )
true = "projects.manage_access" in legacy_manager.scopes

legacy_narrow = Repo.get_by!(ApiToken, name: "Legacy narrow reader")
false = "projects.manage_access" in legacy_narrow.scopes

{:ok, bootstrap} =
  Accounts.bootstrap_owner(
    %{email: "legacy-owner@example.test", display_name: "Legacy Owner"},
    adopt_phase_one: true,
    rotate_token: true
  )

true = bootstrap.organization.id == Accounts.phase_one_organization_id()
true = is_binary(bootstrap.raw_token)
{:ok, auth} = Accounts.authenticate(bootstrap.raw_token)

project = Projects.get_project("11111111-1111-4111-8111-111111111111", auth.organization_id)
true = project.name == "Legacy project"
true = project.creator_actor_id == "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
true = project.inserted_at == ~U[2026-07-01 12:00:00.123456Z]
true = project.updated_at == ~U[2026-07-02 12:00:00.123456Z]

{:ok, memory} =
  Memories.get_memory(
    project.id,
    "22222222-2222-4222-8222-222222222222",
    auth
  )

[revision] = memory.revisions
true = memory.inserted_at == ~U[2026-07-03 12:00:00.123456Z]
true = memory.updated_at == ~U[2026-07-04 12:00:00.123456Z]
true = revision.content == "Durable legacy Phoenix memory"
true = revision.content_hash == String.duplicate("a", 64)
true = revision.actor_id == "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
true = revision.inserted_at == ~U[2026-07-05 12:00:00.123456Z]
true = revision.updated_at == ~U[2026-07-06 12:00:00.123456Z]

{:ok, [result]} = Memories.search(project.id, "phoenix", auth)
true = result.memory_id == memory.id
true = result.actor_id == revision.actor_id
true = result.content_hash == revision.content_hash

true = Repo.aggregate(User, :count, :id) == 3
true = Repo.aggregate(OrganizationMembership, :count, :id) == 3

grants =
  Repo.all(
    from grant in ProjectAccessGrant,
      join: membership in assoc(grant, :organization_membership),
      where: grant.project_id == ^project.id,
      select: {grant, membership.deactivated_at}
  )

true = length(grants) == 2
true = Enum.all?(grants, fn {grant, _deactivated_at} -> grant.access == "editor" end)
true = Enum.count(grants, fn {_grant, deactivated_at} -> not is_nil(deactivated_at) end) == 1

synthetic_ids =
  Repo.all(
    from user in User,
      where:
        user.id in ^[
          "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
          "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        ],
      select: user.id
  )

true =
  MapSet.new(synthetic_ids) ==
    MapSet.new([
      "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
    ])

active_legacy_membership =
  Repo.get_by!(OrganizationMembership,
    user_id: Ecto.UUID.cast!("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
  )

{:ok, _token, active_legacy_raw} =
  Accounts.create_membership_api_token(auth, active_legacy_membership.id, %{
    name: "Upgraded legacy member",
    scopes: ["memory.read"]
  })

{:ok, active_legacy_auth} = Accounts.authenticate(active_legacy_raw)
{:ok, _project} = Projects.authorize_project(project.id, active_legacy_auth, :editor)

inactive_legacy_membership =
  Repo.get_by!(OrganizationMembership,
    user_id: Ecto.UUID.cast!("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
  )

{:ok, _membership} =
  Accounts.reactivate_organization_membership(auth, inactive_legacy_membership.id)

{:ok, _token, reactivated_legacy_raw} =
  Accounts.create_membership_api_token(auth, inactive_legacy_membership.id, %{
    name: "Reactivated legacy member",
    scopes: ["memory.read"]
  })

{:ok, reactivated_legacy_auth} = Accounts.authenticate(reactivated_legacy_raw)
{:ok, _project} = Projects.authorize_project(project.id, reactivated_legacy_auth, :editor)

{:ok, membership} =
  Accounts.create_organization_membership(auth, %{
    email: "upgraded-member@example.test",
    display_name: "Upgraded Member",
    role: "member"
  })

{:ok, _token, raw_token} =
  Accounts.create_membership_api_token(auth, membership.id, %{
    name: "Upgrade reader",
    scopes: ["memory.read"]
  })

{:ok, member_auth} = Accounts.authenticate(raw_token)
true = member_auth.membership_id == membership.id
{:error, :project_not_found} = Projects.authorize_project(project.id, member_auth, :reader)

IO.puts("Phase 2C upgrade passed")
