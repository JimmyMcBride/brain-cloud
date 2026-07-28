.PHONY: setup fmt format-check compile test assets build release run ecto-create ecto-migrate docker-build compose-up compose-down smoke-phase1 check

setup:
	mix deps.get
	mix assets.setup

fmt:
	mix format

format-check:
	mix format --check-formatted

compile:
	mix compile --warnings-as-errors

test:
	MIX_ENV=test mix ecto.create --quiet
	MIX_ENV=test mix ecto.migrate --quiet
	MIX_ENV=test mix test

assets:
	MIX_ENV=prod mix assets.deploy

build:
	mix compile

release:
	MIX_ENV=prod mix assets.deploy
	MIX_ENV=prod mix release brain_cloud --overwrite

run:
	mix phx.server

ecto-create:
	mix ecto.create

ecto-migrate:
	mix ecto.migrate

docker-build:
	docker build -t brain-cloud:dev .

compose-up:
	docker compose up --build

compose-down:
	docker compose down

smoke-phase1:
	sh scripts/phase1-smoke.sh

check:
	mix format --check-formatted
	MIX_ENV=test mix compile --warnings-as-errors
	MIX_ENV=test mix ecto.create --quiet
	MIX_ENV=test mix ecto.migrate --quiet
	MIX_ENV=test mix test
	MIX_ENV=prod mix assets.deploy
