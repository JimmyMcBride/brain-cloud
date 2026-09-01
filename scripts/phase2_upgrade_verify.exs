alias BrainCloud.{Accounts, Agents, Memories, Projects, Repo}
alias BrainCloud.Accounts.{ApiToken, AuditEvent, OrganizationMembership, User}
alias BrainCloud.Agents.Agent
alias BrainCloud.Memories.MemoryRevision
alias BrainCloud.Projects.{AgentProjectAccessGrant, ProjectAccessGrant, TeamProjectAccessGrant}
alias BrainCloud.Teams.{Team, TeamMembership}

import Ecto.Query

legacy_manager =
  Repo.one!(
    from token in ApiToken,
      where: token.name == "Bootstrap owner" and is_nil(token.revoked_at)
  )
true = "projects.manage_access" in legacy_manager.scopes
false = "teams.manage" in legacy_manager.scopes
false = "agents.manage" in legacy_manager.scopes

legacy_full = Repo.get_by!(ApiToken, name: "Legacy full owner")
true = "teams.manage" in legacy_full.scopes
true = "agents.manage" in legacy_full.scopes

legacy_narrow = Repo.get_by!(ApiToken, name: "Legacy narrow reader")
false = "projects.manage_access" in legacy_narrow.scopes
false = "teams.manage" in legacy_narrow.scopes
false = "agents.manage" in legacy_narrow.scopes

for token <- [legacy_manager, legacy_full, legacy_narrow] do
  true = is_binary(token.membership_id)
  true = is_nil(token.agent_id)
end

{:ok, bootstrap} =
  Accounts.bootstrap_owner(
    %{email: "legacy-owner@example.test", display_name: "Legacy Owner"},
    adopt_phase_one: true,
    rotate_token: true
  )

true = bootstrap.organization.id == Accounts.phase_one_organization_id()
true = is_binary(bootstrap.raw_token)
{:ok, auth} = Accounts.authenticate(bootstrap.raw_token)
true = "teams.manage" in auth.scopes
true = "agents.manage" in auth.scopes
true = Repo.aggregate(Team, :count, :id) == 0
true = Repo.aggregate(TeamMembership, :count, :id) == 0
true = Repo.aggregate(TeamProjectAccessGrant, :count, :id) == 0
true = Repo.aggregate(Agent, :count, :id) == 0
true = Repo.aggregate(AgentProjectAccessGrant, :count, :id) == 0
true =
  Repo.aggregate(from(event in AuditEvent, where: not is_nil(event.actor_agent_id)), :count, :id) ==
    0

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
true = revision.actor_user_id == "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
true = is_nil(revision.actor_agent_id)
true = MemoryRevision.actor_type(revision) == "human"
true = MemoryRevision.actor_id(revision) == "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
true = revision.inserted_at == ~U[2026-07-05 12:00:00.123456Z]
true = revision.updated_at == ~U[2026-07-06 12:00:00.123456Z]

{:ok, [result]} = Memories.search(project.id, "phoenix", auth)
true = result.memory_id == memory.id
true = result.actor_type == "human"
true = result.actor_id == revision.actor_user_id
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

{:ok, agent} = Agents.create_agent(%{name: "Upgrade writer"}, auth)

{:ok, grant} =
  Projects.put_agent_project_access_grant(project.id, agent.id, "editor", auth)

true = grant.access == "editor"

{:ok, _agent_token, agent_raw} =
  Agents.create_agent_token(agent.id, %{name: "Upgrade writer", scopes: ["memory.write"]}, auth)

{:ok, agent_auth} = Accounts.authenticate(agent_raw)

{:ok, agent_memory} =
  Memories.create_memory(
    project.id,
    %{title: "Agent upgrade", content: "Agent-authored", content_type: "text/markdown"},
    agent_auth
  )

[agent_revision] = agent_memory.revisions
true = is_nil(agent_revision.actor_user_id)
true = agent_revision.actor_agent_id == agent.id
true = MemoryRevision.actor_type(agent_revision) == "agent"
true = MemoryRevision.actor_id(agent_revision) == agent.id

agent_event = Repo.get_by!(AuditEvent, action: "memory.create", resource_id: agent_memory.id)
true = is_nil(agent_event.actor_user_id)
true = agent_event.actor_agent_id == agent.id

IO.puts("Phase 2F upgrade passed")
