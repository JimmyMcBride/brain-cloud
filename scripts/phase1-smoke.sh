#!/bin/sh
set -eu

compose_project="${COMPOSE_PROJECT_NAME:-brain-cloud}"
base_url="${BASE_URL:-http://127.0.0.1:4000}"
token="${DEV_API_TOKEN:-development-only-token}"
actor_id="${DEV_ACTOR_ID:-00000000-0000-0000-0000-000000000001}"
unauthorized_body="$(mktemp)"

for required_command in curl docker grep jq sha256sum; do
  command -v "$required_command" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$required_command" >&2
    exit 1
  }
done

cleanup() {
  docker compose -p "$compose_project" start postgres >/dev/null 2>&1 || true
  rm -f "$unauthorized_body"
}

trap cleanup EXIT

curl --fail --silent --show-error "$base_url/" |
  grep -q "durable project memory through the public API"

curl --fail --silent --show-error "$base_url/healthz" |
  jq -e '. == {"status":"ok"}' >/dev/null

curl --fail --silent --show-error "$base_url/readyz" |
  jq -e '. == {"status":"ready"}' >/dev/null

curl --fail --silent --show-error "$base_url/v1/system/info" |
  jq -e '.modules == [] and (.capabilities | contains(["system.info", "projects.create", "memory.write", "memory.read", "search.keyword"]))' >/dev/null

unauthorized_status="$(
  curl --silent --show-error \
    --output "$unauthorized_body" \
    --write-out '%{http_code}' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Denied"}' \
    "$base_url/v1/projects"
)"

test "$unauthorized_status" = "401"

jq -e '. == {"error":{"code":"unauthorized","message":"Authentication required","details":{}}}' \
  "$unauthorized_body" >/dev/null

project_response="$(
  curl --fail-with-body --silent --show-error \
    --header "Authorization: Bearer $token" \
    --header 'Content-Type: application/json' \
    --data '{"name":"Compose Research"}' \
    "$base_url/v1/projects"
)"

project_id="$(printf '%s' "$project_response" | jq -er '.project.id')"

printf '%s' "$project_response" |
  jq -e --arg actor_id "$actor_id" \
    '.project.name == "Compose Research" and .project.creator_actor_id == $actor_id' >/dev/null

memory_content='# Durable
Phoenix cloud memory survives restart'

memory_payload="$(
  jq -cn \
    --arg content "$memory_content" \
    '{title:"Phoenix Notes", content:$content, content_type:"text/markdown"}'
)"

memory_response="$(
  curl --fail-with-body --silent --show-error \
    --header "Authorization: Bearer $token" \
    --header 'Content-Type: application/json' \
    --data "$memory_payload" \
    "$base_url/v1/projects/$project_id/memories"
)"

memory_id="$(printf '%s' "$memory_response" | jq -er '.memory.id')"
content_hash="$(printf '%s' "$memory_content" | sha256sum | cut -d' ' -f1)"

printf '%s' "$memory_response" |
  jq -e \
    --arg content "$memory_content" \
    --arg hash "$content_hash" \
    --arg actor_id "$actor_id" \
    '.memory.revision.revision_number == 1 and .memory.revision.content == $content and .memory.revision.content_hash == $hash and .memory.revision.actor_id == $actor_id' >/dev/null

retrieved_before="$(
  curl --fail --silent --show-error \
    --header "Authorization: Bearer $token" \
    "$base_url/v1/projects/$project_id/memories/$memory_id"
)"

test "$(printf '%s' "$memory_response" | jq -S .)" = \
  "$(printf '%s' "$retrieved_before" | jq -S .)"

curl --fail --silent --show-error \
  --header "Authorization: Bearer $token" \
  "$base_url/v1/projects/$project_id/search?q=phoenix" |
  jq -e --arg memory_id "$memory_id" \
    '.results | length == 1 and .[0].memory_id == $memory_id and .[0].revision_number == 1' >/dev/null

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

curl --fail --silent --show-error \
  --header "Authorization: Bearer $token" \
  "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null

curl --fail --silent --show-error \
  --header "Authorization: Bearer $token" \
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
  postgres_health="$(
    docker inspect \
      --format '{{.State.Health.Status}}' \
      "$compose_project-postgres-1" 2>/dev/null || true
  )"

  if [ "$postgres_health" = "healthy" ] &&
    curl --fail --silent --max-time 2 "$base_url/readyz" |
      jq -e '.status == "ready"' >/dev/null 2>&1; then
    break
  fi

  sleep 1
  attempt=$((attempt + 1))
done

test "$attempt" -le 60

curl --fail --silent --show-error \
  --header "Authorization: Bearer $token" \
  "$base_url/v1/projects/$project_id/memories/$memory_id" |
  jq -e --arg memory_id "$memory_id" '.memory.id == $memory_id' >/dev/null

curl --fail --silent --show-error \
  --header "Authorization: Bearer $token" \
  "$base_url/v1/projects/$project_id/search?q=durable" |
  jq -e --arg memory_id "$memory_id" '.results[0].memory_id == $memory_id' >/dev/null

printf 'Phase 1 smoke passed: project=%s memory=%s\n' "$project_id" "$memory_id"
