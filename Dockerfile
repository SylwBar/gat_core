# ---- Build Stage ----
FROM elixir:1.13 as builder
WORKDIR /build
ENV MIX_ENV=prod
COPY lib ./lib
COPY config ./config
COPY mix.exs .
COPY mix.lock .
RUN mix local.rebar --force \
    && mix local.hex --force \
    && mix deps.get \
    && mix release

# ---- Application Stage ----
FROM elixir:1.13
WORKDIR /app
COPY --from=builder /build/config ./config
COPY --from=builder /build/_build/prod/rel/ogn_core/ .
CMD ["/app/bin/ogn_core", "start"]
