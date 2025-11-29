# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?name=ubuntu
# https://hub.docker.com/_/ubuntu/tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian/tags?name=trixie-20251117-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: docker.io/hexpm/elixir:1.18.4-erlang-27.3.4.2-debian-trixie-20251117-slim
#
ARG ELIXIR_VERSION=1.19.4
ARG OTP_VERSION=28.2
ARG DEBIAN_VERSION=trixie-20251117
ARG DISTRO_VERSION=debian-${DEBIAN_VERSION}

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-${DISTRO_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
  && mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.exs
COPY apps/kjogvi_web/mix.exs apps/kjogvi_web/mix.exs
COPY apps/kjogvi/mix.exs apps/kjogvi/mix.exs
COPY apps/ornithologue/mix.exs apps/ornithologue/mix.exs
COPY apps/ornitho_web/mix.exs apps/ornitho_web/mix.exs

COPY mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

RUN mix assets.setup

COPY apps/kjogvi/priv apps/kjogvi/priv
COPY apps/kjogvi_web/priv apps/kjogvi_web/priv
COPY apps/ornithologue/priv apps/ornithologue/priv
COPY apps/ornitho_web/priv apps/ornitho_web/priv

COPY apps/kjogvi/lib apps/kjogvi/lib
COPY apps/kjogvi_web/lib apps/kjogvi_web/lib
COPY apps/ornithologue/lib apps/ornithologue/lib
COPY apps/ornitho_web/lib apps/ornitho_web/lib

# Compile the release

# This is needed for compilation
COPY apps/ornitho_web/dist apps/ornitho_web/dist

RUN mix compile

COPY apps/kjogvi_web/assets apps/kjogvi_web/assets
COPY apps/ornitho_web/assets apps/ornitho_web/assets

# Compile assets
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS final

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates \
  postgresql-client file curl gzip bzip2 net-tools netcat-openbsd bind9-dnsutils procps \
  && rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/kjogvi ./

USER nobody

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENTRYPOINT ["/tini", "--"]

CMD ["/app/bin/server"]
