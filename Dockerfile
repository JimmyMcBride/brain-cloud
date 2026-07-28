# syntax=docker/dockerfile:1

FROM hexpm/elixir:1.20.2-erlang-29.0.3-alpine-3.22.5 AS build

RUN apk add --no-cache build-base git

WORKDIR /src

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
COPY apps/brain_cloud/mix.exs apps/brain_cloud/mix.exs
COPY apps/brain_cloud_web/mix.exs apps/brain_cloud_web/mix.exs

RUN mix deps.get --only prod
RUN mix deps.compile

COPY apps apps
COPY rel rel

RUN mix compile
RUN mix assets.deploy
RUN mix release brain_cloud

FROM alpine:3.22.5 AS runtime

RUN apk add --no-cache ca-certificates libgcc libstdc++ lksctp-tools ncurses-libs openssl \
    && addgroup -S -g 1000 brain \
    && adduser -S -u 1000 -G brain brain

WORKDIR /app

RUN chown brain:brain /app

COPY --from=build --chown=brain:brain /src/_build/prod/rel/brain_cloud ./
COPY --from=build --chown=brain:brain /src/rel/entrypoint.sh /app/entrypoint.sh

ENV HOME=/app
ENV LANG=C.UTF-8
ENV PHX_SERVER=true

EXPOSE 4000

USER brain

ENTRYPOINT ["/app/entrypoint.sh"]
