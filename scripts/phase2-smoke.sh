#!/bin/sh
set -eu

compose_project="${COMPOSE_PROJECT_NAME:-brain-cloud}"
base_url="${BASE_URL:-http://127.0.0.1:4000}"
run_suffix="$(date +%s)-$$"
scratch_dir="$(mktemp -d)"

for required_command in curl docker grep jq sha256sum; do
  command -v "$required_command" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$required_command" >&2
    exit 1
  }
done

cleanup() {
  docker compose -p "$compose_project" start postgres >/dev/null 2>&1 || true
  rm -r "$scratch_dir"
}

trap cleanup EXIT

bootstrap_owner() {
  email="$1"
  display_name="$2"
  organization_name="$3"
  organization_slug="$4"
  recovery="${5:-false}"

  docker compose -p "$compose_project" exec -T \
    -e OWNER_EMAIL="$email" \
    -e OWNER_DISPLAY_NAME="$display_name" \
    -e ORGANIZATION_NAME="$organization_name" \
    -e ORGANIZATION_SLUG="$organization_slug" \
    -e ROTATE_TOKEN="$recovery" \
    api /app/bin/bootstrap_owner
}

authorized_curl() {
  auth_token="$1"
  shift
  curl --fail-with-body --silent --show-error \
    --header "Authorization: Bearer $auth_token" "$@"
}

attempt=1
while [ "$attempt" -le 60 ]; do
  if curl --fail --silent --max-time 2 "$base_url/readyz" |
    jq -e '.status == "ready"' >/dev/null 2>&1; then
    break
  fi
  sleep 1
  attempt=$((attempt + 1))
done
test "$attempt" -le 60

curl --fail --silent --show-error "$base_url/" |
  grep -q "organization-scoped durable"
curl --fail --silent --show-error "$base_url/" |
  grep -q "bounded agent-authored writes"

curl --fail --silent --show-error "$base_url/healthz" |
  jq -e '. == {"status":"ok"}' >/dev/null

curl --fail --silent --show-error "$base_url/readyz" |
  jq -e '. == {"status":"ready"}' >/dev/null

curl --fail --silent --show-error "$base_url/v1/system/info" |
  jq -e '.modules == [] and (.capabilities | contains(["system.info", "projects.create", "projects.manage_access", "memory.write", "memory.read", "search.keyword", "members.manage", "teams.manage", "agents.manage", "tokens.manage"]))' >/dev/null

organization_a_slug="smoke-a-$run_suffix"
organization_b_slug="smoke-b-$run_suffix"

bootstrap_a="$(
  bootstrap_owner \
    "owner-a-$run_suffix@example.test" \
    "Smoke Owner A" \
    "Smoke Organization A $run_suffix" \
    "$organization_a_slug"
)"
token_a="$(printf '%s' "$bootstrap_a" | jq -er '.token')"
organization_a_id="$(printf '%s' "$bootstrap_a" | jq -er '.organization_id')"

repeated_a="$(
  bootstrap_owner \
    "owner-a-$run_suffix@example.test" \
    "Smoke Owner A" \
    "Smoke Organization A $run_suffix" \
    "$organization_a_slug"
)"
printf '%s' "$repeated_a" |
  jq -e '.status == "existing" and .token == null' >/dev/null

bootstrap_b="$(
  bootstrap_owner \
    "owner-b-$run_suffix@example.test" \
    "Smoke Owner B" \
    "Smoke Organization B $run_suffix" \
    "$organization_b_slug"
)"
token_b="$(printf '%s' "$bootstrap_b" | jq -er '.token')"

invitation_expires_at="$(date -u -d '+1 hour' '+%Y-%m-%dT%H:%M:%SZ')"
invitee_email="invitee-$run_suffix@example.test"
invitation_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data "$(
      jq -cn \
        --arg email "$invitee_email" \
        --arg expires_at "$invitation_expires_at" \
        '{email:$email,display_name:"Smoke Invitee",scopes:["projects.create","memory.write","memory.read","search.keyword"],expires_at:$expires_at}'
    )" \
    "$base_url/v1/organization/invitations"
)"
invitation_id="$(printf '%s' "$invitation_response" | jq -er '.invitation.id')"
acceptance_token="$(printf '%s' "$invitation_response" | jq -er '.acceptance_token')"
printf '%s' "$acceptance_token" | grep -Eq '^bci1_[0-9a-f]{32}_[A-Za-z0-9_-]{43}$'

authorized_curl "$token_a" "$base_url/v1/organization/invitations" |
  jq -e --arg id "$invitation_id" --arg secret "$acceptance_token" \
    '(.invitations | map(select(.id == $id and .status == "pending")) | length) == 1 and
     (tostring | contains($secret) | not) and
     (tostring | contains("secret_digest") | not)' >/dev/null

cross_invitation_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/cross-invitation.json" \
    --write-out '%{http_code}' \
    --request DELETE \
    --header "Authorization: Bearer $token_b" \
    "$base_url/v1/organization/invitations/$invitation_id"
)"
test "$cross_invitation_status" = "404"
jq -e '.error.code == "invitation_not_found"' "$scratch_dir/cross-invitation.json" >/dev/null

acceptance_response="$(
  curl --fail-with-body --silent --show-error \
    --header 'Content-Type: application/json' \
    --data "$(jq -cn --arg token "$acceptance_token" '{acceptance_token:$token}')" \
    "$base_url/v1/invitations/accept"
)"
invitee_membership_id="$(printf '%s' "$acceptance_response" | jq -er '.membership.id')"
invitee_token="$(printf '%s' "$acceptance_response" | jq -er '.token.token')"
printf '%s' "$acceptance_response" |
  jq -e --arg email "$invitee_email" \
    '.membership.email == $email and .membership.role == "member" and
     .token.name == "Invitation acceptance" and .token.expires_at == null' >/dev/null

replay_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/invitation-replay.json" \
    --write-out '%{http_code}' \
    --header 'Content-Type: application/json' \
    --data "$(jq -cn --arg token "$acceptance_token" '{acceptance_token:$token}')" \
    "$base_url/v1/invitations/accept"
)"
test "$replay_status" = "404"
jq -e '.error.code == "invitation_not_found"' "$scratch_dir/invitation-replay.json" >/dev/null

invitee_project_response="$(
  authorized_curl "$invitee_token" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Invitation project"}' \
    "$base_url/v1/projects"
)"
invitee_project_id="$(printf '%s' "$invitee_project_response" | jq -er '.project.id')"
invitee_memory_response="$(
  authorized_curl "$invitee_token" \
    --header 'Content-Type: application/json' \
    --data '{"title":"Accepted","content":"Invitation credential works","content_type":"text/markdown"}' \
    "$base_url/v1/projects/$invitee_project_id/memories"
)"
invitee_memory_id="$(printf '%s' "$invitee_memory_response" | jq -er '.memory.id')"
printf '%s' "$invitee_memory_response" |
  jq -e '.memory.revision.actor_type == "human"' >/dev/null

revoked_email="revoked-invitee-$run_suffix@example.test"
revoked_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data "$(jq -cn --arg email "$revoked_email" --arg expires_at "$invitation_expires_at" '{email:$email,display_name:"Revoked Invitee",scopes:["memory.read"],expires_at:$expires_at}')" \
    "$base_url/v1/organization/invitations"
)"
revoked_id="$(printf '%s' "$revoked_response" | jq -er '.invitation.id')"
revoked_secret="$(printf '%s' "$revoked_response" | jq -er '.acceptance_token')"
authorized_curl "$token_a" --request DELETE \
  "$base_url/v1/organization/invitations/$revoked_id" >/dev/null

revoked_accept_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/revoked-invitation.json" \
    --write-out '%{http_code}' \
    --header 'Content-Type: application/json' \
    --data "$(jq -cn --arg token "$revoked_secret" '{acceptance_token:$token}')" \
    "$base_url/v1/invitations/accept"
)"
test "$revoked_accept_status" = "404"

reissued_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data "$(jq -cn --arg email "$revoked_email" --arg expires_at "$invitation_expires_at" '{email:$email,display_name:"Reissued Invitee",scopes:["memory.read"],expires_at:$expires_at}')" \
    "$base_url/v1/organization/invitations"
)"
reissued_secret="$(printf '%s' "$reissued_response" | jq -er '.acceptance_token')"
curl --fail-with-body --silent --show-error \
  --header 'Content-Type: application/json' \
  --data "$(jq -cn --arg token "$reissued_secret" '{acceptance_token:$token}')" \
  "$base_url/v1/invitations/accept" |
  jq -e --arg email "$revoked_email" '.membership.email == $email' >/dev/null

existing_user_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data "$(jq -cn --arg email "owner-b-$run_suffix@example.test" --arg expires_at "$invitation_expires_at" '{email:$email,display_name:"Must Not Replace",scopes:["memory.read"],expires_at:$expires_at}')" \
    "$base_url/v1/organization/invitations"
)"
existing_user_secret="$(printf '%s' "$existing_user_response" | jq -er '.acceptance_token')"
curl --fail-with-body --silent --show-error \
  --header 'Content-Type: application/json' \
  --data "$(jq -cn --arg token "$existing_user_secret" '{acceptance_token:$token}')" \
  "$base_url/v1/invitations/accept" |
  jq -e '.membership.display_name == "Smoke Owner B" and .membership.role == "member"' >/dev/null

second_owner_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data "{\"email\":\"second-owner-$run_suffix@example.test\",\"display_name\":\"Second Owner\",\"role\":\"owner\"}" \
    "$base_url/v1/organization/memberships"
)"
second_owner_id="$(printf '%s' "$second_owner_response" | jq -er '.membership.id')"

second_owner_token_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Second owner","scopes":["projects.create","projects.manage_access","memory.write","memory.read","search.keyword","members.manage","teams.manage","tokens.manage"]}' \
    "$base_url/v1/organization/memberships/$second_owner_id/tokens"
)"
second_owner_token="$(printf '%s' "$second_owner_token_response" | jq -er '.token.token')"

member_response="$(
  authorized_curl "$second_owner_token" \
    --header 'Content-Type: application/json' \
    --data "{\"email\":\"member-$run_suffix@example.test\",\"display_name\":\"Smoke Member\",\"role\":\"member\"}" \
    "$base_url/v1/organization/memberships"
)"
member_id="$(printf '%s' "$member_response" | jq -er '.membership.id')"

member_token_response="$(
  authorized_curl "$second_owner_token" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Member project operator","scopes":["memory.write","memory.read","search.keyword"]}' \
    "$base_url/v1/organization/memberships/$member_id/tokens"
)"
member_token="$(printf '%s' "$member_token_response" | jq -er '.token.token')"

unauthorized_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/unauthorized.json" \
    --write-out '%{http_code}' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Denied"}' \
    "$base_url/v1/projects"
)"
test "$unauthorized_status" = "401"
jq -e '. == {"error":{"code":"unauthorized","message":"Authentication required","details":{}}}' \
  "$scratch_dir/unauthorized.json" >/dev/null

project_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Tenant A Research"}' \
    "$base_url/v1/projects"
)"
project_id="$(printf '%s' "$project_response" | jq -er '.project.id')"

printf '%s' "$project_response" |
  jq -e --arg organization_id "$organization_a_id" \
    '.project.name == "Tenant A Research" and .project.organization_id == $organization_id' >/dev/null

reader_write_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/reader-write.json" \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer $member_token" \
    --header 'Content-Type: application/json' \
    --data '{"title":"Denied","content":"Denied","content_type":"text/markdown"}' \
    "$base_url/v1/projects/$project_id/memories"
)"
test "$reader_write_status" = "404"
jq -e '.error.code == "project_not_found"' "$scratch_dir/reader-write.json" >/dev/null

team_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Smoke readers"}' \
    "$base_url/v1/organization/teams"
)"
team_id="$(printf '%s' "$team_response" | jq -er '.team.id')"

authorized_curl "$token_a" \
  --request PUT \
  "$base_url/v1/organization/teams/$team_id/members/$member_id" |
  jq -e --arg team_id "$team_id" --arg member_id "$member_id" \
    '.team_membership.team_id == $team_id and .team_membership.membership_id == $member_id' >/dev/null

authorized_curl "$token_a" \
  --request PUT \
  --header 'Content-Type: application/json' \
  --data '{"access":"reader"}' \
  "$base_url/v1/projects/$project_id/team-access/$team_id" |
  jq -e --arg team_id "$team_id" \
    '.team_access_grant.team_id == $team_id and .team_access_grant.access == "reader"' >/dev/null

team_memory_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data '{"title":"Team visible","content":"Team access check","content_type":"text/markdown"}' \
    "$base_url/v1/projects/$project_id/memories"
)"
team_memory_id="$(printf '%s' "$team_memory_response" | jq -er '.memory.id')"
authorized_curl "$member_token" "$base_url/v1/projects/$project_id/memories/$team_memory_id" |
  jq -e --arg memory_id "$team_memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$token_a" --request DELETE "$base_url/v1/organization/teams/$team_id" >/dev/null
team_inactive_status="$(
  curl --silent --show-error --output "$scratch_dir/team-inactive.json" --write-out '%{http_code}' \
    --header "Authorization: Bearer $member_token" \
    "$base_url/v1/projects/$project_id/memories/$team_memory_id"
)"
test "$team_inactive_status" = "404"
jq -e '.error.code == "project_not_found"' "$scratch_dir/team-inactive.json" >/dev/null

authorized_curl "$token_a" --request POST \
  "$base_url/v1/organization/teams/$team_id/reactivate" |
  jq -e '.team.active == true' >/dev/null
authorized_curl "$member_token" "$base_url/v1/projects/$project_id/memories/$team_memory_id" |
  jq -e --arg memory_id "$team_memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$token_a" --request DELETE \
  "$base_url/v1/projects/$project_id/team-access/$team_id" >/dev/null

grant_response="$(
  authorized_curl "$token_a" \
    --request PUT \
    --header 'Content-Type: application/json' \
    --data '{"access":"reader"}' \
    "$base_url/v1/projects/$project_id/access/$member_id"
)"
grant_id="$(printf '%s' "$grant_response" | jq -er '.access_grant.id')"

authorized_curl "$token_a" "$base_url/v1/projects/$project_id/access" |
  jq -e --arg grant_id "$grant_id" --arg member_id "$member_id" \
    '.access_grants == [(.access_grants[0])] and
     .access_grants[0].id == $grant_id and
     .access_grants[0].membership_id == $member_id and
     .access_grants[0].access == "reader"' >/dev/null

reader_memory_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data '{"title":"Reader visible","content":"Reader access check","content_type":"text/markdown"}' \
    "$base_url/v1/projects/$project_id/memories"
)"
reader_memory_id="$(printf '%s' "$reader_memory_response" | jq -er '.memory.id')"

authorized_curl "$member_token" \
  "$base_url/v1/projects/$project_id/memories/$reader_memory_id" |
  jq -e --arg memory_id "$reader_memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$member_token" \
  "$base_url/v1/projects/$project_id/search?q=reader" |
  jq -e --arg memory_id "$reader_memory_id" \
    'any(.results[]; .memory_id == $memory_id)' >/dev/null

reader_write_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/reader-write.json" \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer $member_token" \
    --header 'Content-Type: application/json' \
    --data '{"title":"Denied","content":"Denied","content_type":"text/markdown"}' \
    "$base_url/v1/projects/$project_id/memories"
)"
test "$reader_write_status" = "404"
jq -e '.error.code == "project_not_found"' "$scratch_dir/reader-write.json" >/dev/null

authorized_curl "$token_a" \
  --request PUT \
  --header 'Content-Type: application/json' \
  --data '{"access":"editor"}' \
  "$base_url/v1/projects/$project_id/access/$member_id" |
  jq -e --arg grant_id "$grant_id" \
    '.access_grant.id == $grant_id and .access_grant.access == "editor"' >/dev/null

authorized_curl "$member_token" \
  --header 'Content-Type: application/json' \
  --data '{"title":"Member memory","content":"Member editor write","content_type":"text/markdown"}' \
  "$base_url/v1/projects/$project_id/memories" |
  jq -e '.memory.revision.title == "Member memory"' >/dev/null

memory_content='# Durable
Organization-scoped Phoenix cloud memory survives restart'
memory_payload="$(
  jq -cn \
    --arg content "$memory_content" \
    '{title:"Phoenix Notes", content:$content, content_type:"text/markdown"}'
)"
memory_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data "$memory_payload" \
    "$base_url/v1/projects/$project_id/memories"
)"
memory_id="$(printf '%s' "$memory_response" | jq -er '.memory.id')"
content_hash="$(printf '%s' "$memory_content" | sha256sum | cut -d' ' -f1)"

printf '%s' "$memory_response" |
  jq -e --arg content "$memory_content" --arg hash "$content_hash" \
    '.memory.revision.content == $content and
     .memory.revision.content_hash == $hash and
     .memory.revision.actor_type == "human"' >/dev/null

agent_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Smoke retriever"}' \
    "$base_url/v1/organization/agents"
)"
agent_id="$(printf '%s' "$agent_response" | jq -er '.agent.id')"

agent_token_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Smoke agent writer","scopes":["memory.write","memory.read","search.keyword"]}' \
    "$base_url/v1/organization/agents/$agent_id/tokens"
)"
agent_token_id="$(printf '%s' "$agent_token_response" | jq -er '.token.id')"
agent_token="$(printf '%s' "$agent_token_response" | jq -er '.token.token')"

authorized_curl "$token_a" \
  --request PUT \
  --header 'Content-Type: application/json' \
  --data '{"access":"reader"}' \
  "$base_url/v1/projects/$project_id/agent-access/$agent_id" |
  jq -e --arg agent_id "$agent_id" \
    '.agent_access_grant.agent_id == $agent_id and .agent_access_grant.access == "reader"' >/dev/null

authorized_curl "$agent_token" "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null
authorized_curl "$agent_token" "$base_url/v1/projects/$project_id/search?q=phoenix" |
  jq -e --arg memory_id "$memory_id" 'any(.results[]; .memory_id == $memory_id)' >/dev/null

agent_write_status="$(
  curl --silent --show-error --output "$scratch_dir/agent-write.json" --write-out '%{http_code}' \
    --header "Authorization: Bearer $agent_token" \
    --header 'Content-Type: application/json' \
    --data '{"title":"Denied","content":"Denied","content_type":"text/markdown"}' \
    "$base_url/v1/projects/$project_id/memories"
)"
test "$agent_write_status" = "404"
jq -e '.error.code == "project_not_found"' "$scratch_dir/agent-write.json" >/dev/null

authorized_curl "$token_a" \
  --request PUT \
  --header 'Content-Type: application/json' \
  --data '{"access":"editor"}' \
  "$base_url/v1/projects/$project_id/agent-access/$agent_id" |
  jq -e --arg agent_id "$agent_id" \
    '.agent_access_grant.agent_id == $agent_id and .agent_access_grant.access == "editor"' >/dev/null

agent_memory_response="$(
  authorized_curl "$agent_token" \
    --header 'Content-Type: application/json' \
    --data '{"title":"Agent memory","content":"Agent provenance survives restart","content_type":"text/markdown"}' \
    "$base_url/v1/projects/$project_id/memories"
)"
agent_memory_id="$(printf '%s' "$agent_memory_response" | jq -er '.memory.id')"

printf '%s' "$agent_memory_response" |
  jq -e --arg agent_id "$agent_id" \
    '.memory.revision.actor_type == "agent" and
     .memory.revision.actor_id == $agent_id and
     .memory.revision.title == "Agent memory"' >/dev/null

authorized_curl "$agent_token" "$base_url/v1/projects/$project_id/memories/$agent_memory_id" |
  jq -e --arg agent_id "$agent_id" \
    '.memory.revision.actor_type == "agent" and .memory.revision.actor_id == $agent_id' >/dev/null

authorized_curl "$agent_token" "$base_url/v1/projects/$project_id/search?q=provenance" |
  jq -e --arg memory_id "$agent_memory_id" --arg agent_id "$agent_id" \
    'any(.results[];
      .memory_id == $memory_id and .actor_type == "agent" and .actor_id == $agent_id)' >/dev/null

authorized_curl "$token_a" \
  --request PUT \
  --header 'Content-Type: application/json' \
  --data '{"access":"reader"}' \
  "$base_url/v1/projects/$project_id/agent-access/$agent_id" |
  jq -e '.agent_access_grant.access == "reader"' >/dev/null

downgraded_agent_write_status="$(
  curl --silent --show-error --output "$scratch_dir/downgraded-agent-write.json" --write-out '%{http_code}' \
    --header "Authorization: Bearer $agent_token" \
    --header 'Content-Type: application/json' \
    --data '{"title":"Denied","content":"Denied","content_type":"text/markdown"}' \
    "$base_url/v1/projects/$project_id/memories"
)"
test "$downgraded_agent_write_status" = "404"
jq -e '.error.code == "project_not_found"' "$scratch_dir/downgraded-agent-write.json" >/dev/null

authorized_curl "$agent_token" "$base_url/v1/projects/$project_id/memories/$agent_memory_id" |
  jq -e --arg memory_id "$agent_memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$token_a" \
  --request PUT \
  --header 'Content-Type: application/json' \
  --data '{"access":"editor"}' \
  "$base_url/v1/projects/$project_id/agent-access/$agent_id" |
  jq -e '.agent_access_grant.access == "editor"' >/dev/null

agent_manage_status="$(
  curl --silent --show-error --output "$scratch_dir/agent-manage.json" --write-out '%{http_code}' \
    --header "Authorization: Bearer $agent_token" \
    "$base_url/v1/organization/agents"
)"
test "$agent_manage_status" = "403"
jq -e '.error.code == "forbidden"' "$scratch_dir/agent-manage.json" >/dev/null

cross_agent_status="$(
  curl --silent --show-error --output "$scratch_dir/cross-agent.json" --write-out '%{http_code}' \
    --request PATCH \
    --header "Authorization: Bearer $token_b" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Hidden"}' \
    "$base_url/v1/organization/agents/$agent_id"
)"
test "$cross_agent_status" = "404"
jq -e '.error.code == "agent_not_found"' "$scratch_dir/cross-agent.json" >/dev/null

authorized_curl "$token_a" --request DELETE \
  "$base_url/v1/organization/agents/$agent_id" >/dev/null

inactive_agent_status="$(
  curl --silent --show-error --output "$scratch_dir/inactive-agent.json" --write-out '%{http_code}' \
    --header "Authorization: Bearer $agent_token" \
    "$base_url/v1/projects/$project_id/memories/$memory_id"
)"
test "$inactive_agent_status" = "401"

authorized_curl "$token_a" --request POST \
  "$base_url/v1/organization/agents/$agent_id/reactivate" |
  jq -e '.agent.active == true' >/dev/null

old_agent_status="$(
  curl --silent --show-error --output "$scratch_dir/old-agent.json" --write-out '%{http_code}' \
    --header "Authorization: Bearer $agent_token" \
    "$base_url/v1/projects/$project_id/memories/$memory_id"
)"
test "$old_agent_status" = "401"

fresh_agent_token_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Fresh smoke agent writer","scopes":["memory.write","memory.read","search.keyword"]}' \
    "$base_url/v1/organization/agents/$agent_id/tokens"
)"
fresh_agent_token_id="$(printf '%s' "$fresh_agent_token_response" | jq -er '.token.id')"
fresh_agent_token="$(printf '%s' "$fresh_agent_token_response" | jq -er '.token.token')"

authorized_curl "$fresh_agent_token" "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$fresh_agent_token" \
  --header 'Content-Type: application/json' \
  --data '{"title":"Reactivated agent memory","content":"Fresh credential write","content_type":"text/markdown"}' \
  "$base_url/v1/projects/$project_id/memories" |
  jq -e --arg agent_id "$agent_id" \
    '.memory.revision.actor_type == "agent" and .memory.revision.actor_id == $agent_id' >/dev/null

authorized_curl "$token_a" --request DELETE \
  "$base_url/v1/organization/agents/$agent_id/tokens/$fresh_agent_token_id" >/dev/null

revoked_agent_token_status="$(
  curl --silent --show-error --output "$scratch_dir/revoked-agent-token.json" --write-out '%{http_code}' \
    --header "Authorization: Bearer $fresh_agent_token" \
    "$base_url/v1/projects/$project_id/memories/$agent_memory_id"
)"
test "$revoked_agent_token_status" = "401"

replacement_agent_token_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Replacement smoke agent","scopes":["memory.write","memory.read","search.keyword"]}' \
    "$base_url/v1/organization/agents/$agent_id/tokens"
)"
fresh_agent_token="$(printf '%s' "$replacement_agent_token_response" | jq -er '.token.token')"

authorized_curl "$token_a" "$base_url/v1/auth/tokens" |
  jq -e --arg agent_token_id "$agent_token_id" \
    'all(.tokens[]; .id != $agent_token_id)' >/dev/null

for tenant_b_path in \
  "$base_url/v1/projects/$project_id/memories/$memory_id" \
  "$base_url/v1/projects/$project_id/search?q=phoenix"; do
  cross_status="$(
    curl --silent --show-error \
      --output "$scratch_dir/cross-tenant.json" \
      --write-out '%{http_code}' \
      --header "Authorization: Bearer $token_b" \
      "$tenant_b_path"
  )"
  test "$cross_status" = "404"
  jq -e '.error.code == "project_not_found"' "$scratch_dir/cross-tenant.json" >/dev/null
done

cross_write_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/cross-write.json" \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer $token_b" \
    --header 'Content-Type: application/json' \
    --data "$memory_payload" \
    "$base_url/v1/projects/$project_id/memories"
)"
test "$cross_write_status" = "404"
jq -e '.error.code == "project_not_found"' "$scratch_dir/cross-write.json" >/dev/null

created_token="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Smoke reader","scopes":["memory.read","search.keyword"]}' \
    "$base_url/v1/auth/tokens"
)"
reader_id="$(printf '%s' "$created_token" | jq -er '.token.id')"
reader_token="$(printf '%s' "$created_token" | jq -er '.token.token')"

authorized_curl "$token_a" "$base_url/v1/auth/tokens" |
  jq -e --arg id "$reader_id" \
    '(.tokens | map(select(.id == $id)) | length) == 1 and
     (tostring | contains("token_digest") | not)' >/dev/null

authorized_curl "$reader_token" \
  "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$member_token" \
  "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$second_owner_token" \
  --request DELETE \
  "$base_url/v1/organization/memberships/$member_id" >/dev/null

suspended_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/suspended.json" \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer $member_token" \
    "$base_url/v1/projects/$project_id/memories/$memory_id"
)"
test "$suspended_status" = "401"

authorized_curl "$token_a" \
  --request POST \
  "$base_url/v1/organization/memberships/$member_id/reactivate" |
  jq -e '.membership.active == true and .membership.deactivated_at == null' >/dev/null

restored_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/not-restored.json" \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer $member_token" \
    "$base_url/v1/projects/$project_id/memories/$memory_id"
)"
test "$restored_status" = "401"

replacement_member_response="$(
  authorized_curl "$token_a" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Replacement member reader","scopes":["memory.read","search.keyword"]}' \
    "$base_url/v1/organization/memberships/$member_id/tokens"
)"
replacement_member_token="$(
  printf '%s' "$replacement_member_response" | jq -er '.token.token'
)"

authorized_curl "$token_a" \
  --request PATCH \
  --header 'Content-Type: application/json' \
  --data '{"role":"member"}' \
  "$base_url/v1/organization/memberships/$second_owner_id" |
  jq -e '.membership.role == "member"' >/dev/null

demoted_owner_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/demoted-owner.json" \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer $second_owner_token" \
    "$base_url/v1/organization/memberships"
)"
test "$demoted_owner_status" = "401"

last_owner_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/last-owner.json" \
    --write-out '%{http_code}' \
    --request PATCH \
    --header "Authorization: Bearer $token_a" \
    --header 'Content-Type: application/json' \
    --data '{"role":"member"}' \
    "$base_url/v1/organization/memberships/$(printf '%s' "$bootstrap_a" | jq -er '.membership_id')"
)"
test "$last_owner_status" = "409"
jq -e '.error.code == "last_owner_required"' "$scratch_dir/last-owner.json" >/dev/null

authorized_curl "$token_a" \
  --request DELETE \
  "$base_url/v1/auth/tokens/$reader_id" >/dev/null

revoked_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/revoked.json" \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer $reader_token" \
    "$base_url/v1/projects/$project_id/memories/$memory_id"
)"
test "$revoked_status" = "401"

docker compose -p "$compose_project" restart api >/dev/null

attempt=1
while [ "$attempt" -le 60 ]; do
  if curl --fail --silent --max-time 2 "$base_url/readyz" |
    jq -e '.status == "ready"' >/dev/null 2>&1; then
    break
  fi
  sleep 1
  attempt=$((attempt + 1))
done
test "$attempt" -le 60

authorized_curl "$token_a" \
  "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$token_a" "$base_url/v1/organization/invitations" |
  jq -e --arg id "$invitation_id" --arg membership_id "$invitee_membership_id" \
    '(.invitations | map(select(.id == $id and .status == "accepted" and .accepted_membership_id == $membership_id)) | length) == 1' >/dev/null

authorized_curl "$invitee_token" \
  "$base_url/v1/projects/$invitee_project_id/memories/$invitee_memory_id" |
  jq -e --arg memory_id "$invitee_memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$replacement_member_token" \
  "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$fresh_agent_token" \
  "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$fresh_agent_token" \
  "$base_url/v1/projects/$project_id/memories/$agent_memory_id" |
  jq -e --arg memory_id "$agent_memory_id" --arg agent_id "$agent_id" \
    '.memory.id == $memory_id and
     .memory.revision.actor_type == "agent" and
     .memory.revision.actor_id == $agent_id' >/dev/null

rotated_a="$(
  bootstrap_owner \
    "owner-a-$run_suffix@example.test" \
    "Smoke Owner A" \
    "Smoke Organization A $run_suffix" \
    "$organization_a_slug" \
    true
)"
replacement_token="$(printf '%s' "$rotated_a" | jq -er '.token')"

old_token_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/rotated.json" \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer $token_a" \
    "$base_url/v1/projects/$project_id/memories/$memory_id"
)"
test "$old_token_status" = "401"

authorized_curl "$replacement_token" \
  "$base_url/v1/projects/$project_id/search?q=restart" |
  jq -e --arg memory_id "$memory_id" '.results[0].memory_id == $memory_id' >/dev/null

docker compose -p "$compose_project" stop postgres >/dev/null

health_status="$(
  curl --silent --output /dev/null --write-out '%{http_code}' --max-time 5 \
    "$base_url/healthz"
)"
readiness_status="$(
  curl --silent --output /dev/null --write-out '%{http_code}' --max-time 10 \
    "$base_url/readyz"
)"
test "$health_status" = "200"
test "$readiness_status" = "503"

docker compose -p "$compose_project" start postgres >/dev/null

attempt=1
while [ "$attempt" -le 60 ]; do
  if curl --fail --silent --max-time 2 "$base_url/readyz" |
    jq -e '.status == "ready"' >/dev/null 2>&1; then
    break
  fi
  sleep 1
  attempt=$((attempt + 1))
done
test "$attempt" -le 60

authorized_curl "$replacement_token" \
  "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$replacement_member_token" \
  "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$fresh_agent_token" \
  "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null

authorized_curl "$fresh_agent_token" \
  "$base_url/v1/projects/$project_id/memories/$agent_memory_id" |
  jq -e --arg memory_id "$agent_memory_id" --arg agent_id "$agent_id" \
    '.memory.id == $memory_id and
     .memory.revision.actor_type == "agent" and
     .memory.revision.actor_id == $agent_id' >/dev/null

authorized_curl "$replacement_token" \
  --request DELETE \
  "$base_url/v1/projects/$project_id/access/$member_id" >/dev/null

authorized_curl "$replacement_token" \
  --request DELETE \
  "$base_url/v1/projects/$project_id/access/$member_id" >/dev/null

revoked_access_status="$(
  curl --silent --show-error \
    --output "$scratch_dir/revoked-access.json" \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer $replacement_member_token" \
    "$base_url/v1/projects/$project_id/memories/$memory_id"
)"
test "$revoked_access_status" = "404"
jq -e '.error.code == "project_not_found"' "$scratch_dir/revoked-access.json" >/dev/null

authorized_curl "$replacement_token" --request DELETE \
  "$base_url/v1/projects/$project_id/agent-access/$agent_id" >/dev/null

revoked_agent_access_status="$(
  curl --silent --show-error --output "$scratch_dir/revoked-agent-access.json" --write-out '%{http_code}' \
    --header "Authorization: Bearer $fresh_agent_token" \
    "$base_url/v1/projects/$project_id/memories/$memory_id"
)"
test "$revoked_agent_access_status" = "404"
jq -e '.error.code == "project_not_found"' "$scratch_dir/revoked-agent-access.json" >/dev/null

printf 'Phase 2G smoke passed: organization=%s project=%s memory=%s member=%s invitee=%s team=%s agent=%s\n' \
  "$organization_a_id" "$project_id" "$memory_id" "$member_id" "$invitee_membership_id" "$team_id" "$agent_id"
