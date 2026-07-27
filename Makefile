.PHONY: fmt test vet build run docker-build compose-up compose-down check

fmt:
	gofmt -w $$(find . -name '*.go' -not -path './.git/*')

test:
	go test ./...

vet:
	go vet ./...

build:
	go build ./...

run:
	go run ./cmd/api

docker-build:
	docker build -t brain-cloud:dev .

compose-up:
	docker compose up --build

compose-down:
	docker compose down

check:
	test -z "$$(gofmt -l .)"
	go test ./...
	go vet ./...
	go build ./cmd/api
	go build ./cmd/worker
