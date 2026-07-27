# syntax=docker/dockerfile:1
FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/brain-cloud-api ./cmd/api

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/brain-cloud-api /brain-cloud-api
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/brain-cloud-api"]
