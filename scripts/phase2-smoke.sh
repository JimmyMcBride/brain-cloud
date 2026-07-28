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
  if curl --fail --silent --max-time 2 "$base_url/healthz" |
    jq -e '.status == "ok"' >/dev/null 2>&1; then
    break
  fi
  sleep 1
  attempt=$((attempt + 1))
done
test "$attempt" -le 60

curl --fail --silent --show-error "$base_url/" |
  grep -q "organization-scoped durable"

curl --fail --silent --show-error "$base_url/healthz" |
  jq -e '. == {"status":"ok"}' >/dev/null

curl --fail --silent --show-error "$base_url/readyz" |
  jq -e '. == {"status":"ready"}' >/dev/null

curl --fail --silent --show-error "$base_url/v1/system/info" |
  jq -e '.modules == [] and (.capabilities | contains(["system.info", "projects.create", "memory.write", "memory.read", "search.keyword", "tokens.manage"]))' >/dev/null

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
    '.memory.revision.content == $content and .memory.revision.content_hash == $hash' >/dev/null

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
  if curl --fail --silent --max-time 2 "$base_url/healthz" |
    jq -e '.status == "ok"' >/dev/null 2>&1; then
    break
  fi
  sleep 1
  attempt=$((attempt + 1))
done
test "$attempt" -le 60

authorized_curl "$token_a" \
  "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null

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

printf 'Phase 2A smoke passed: organization=%s project=%s memory=%s\n' \
  "$organization_a_id" "$project_id" "$memory_id"
