# syntax=docker/dockerfile:1

# Dockerfile used to build a deployable image for the kjogvi Elixir/Phoenix app.
#
# Toolchain and OS packages live in prebuilt images:
#   public.ecr.aws/m7x1i1o0/kjogvi-base   - debian + runtime packages
#   public.ecr.aws/m7x1i1o0/kjogvi-build  - hexpm/elixir on the same debian + build toolchain + node
# Built from https://github.com/khustochka/vk-build-images
# To bump Elixir/OTP/Debian/Node, rebuild those images and update the tags below.

#######################################################################

ARG BASE_IMAGE=public.ecr.aws/m7x1i1o0/kjogvi-base:debiantrixie-20260518-20260602-151242
ARG BUILD_IMAGE=public.ecr.aws/m7x1i1o0/kjogvi-build:elixir1.19.5-otp28.5.0.1-debiantrixie-20260518-node24.16.0-20260602-151242

#######################################################################

FROM ${BUILD_IMAGE} AS builder

# prepare build dir
WORKDIR /app

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

COPY apps/kjogvi/lib apps/kjogvi/lib
COPY apps/kjogvi_web/lib apps/kjogvi_web/lib
COPY apps/ornithologue/lib apps/ornithologue/lib
COPY apps/ornitho_web/lib apps/ornitho_web/lib

COPY apps/kjogvi/priv apps/kjogvi/priv
COPY apps/kjogvi_web/priv apps/kjogvi_web/priv
COPY apps/ornithologue/priv apps/ornithologue/priv
COPY apps/ornitho_web/priv apps/ornitho_web/priv

COPY apps/kjogvi_web/assets apps/kjogvi_web/assets
COPY apps/ornitho_web/assets apps/ornitho_web/assets
COPY apps/ornitho_web/dist apps/ornitho_web/dist

# Compile the release
RUN mix compile

# compile assets
RUN cd apps/kjogvi_web/assets && npm install
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

#######################################################################

# Deployable image
FROM ${BASE_IMAGE}

# Labels
ARG GIT_REVISION=unspecified
ARG GIT_REPOSITORY_URL=unspecified
LABEL org.opencontainers.image.title="kjogvi"
LABEL org.opencontainers.image.revision=$GIT_REVISION
LABEL org.opencontainers.image.source=$GIT_REPOSITORY_URL

ENV GIT_REVISION=${GIT_REVISION}
ENV GIT_REPOSITORY_URL=${GIT_REPOSITORY_URL}
# ENV DD_CONTAINER_LABELS_AS_TAGS='{"org.opencontainers.image.source":"git.repository_url","org.opencontainers.image.revision":"git.commit.sha"}'
# Datadog expects repo URL without protocol.
ENV DD_TAGS="git.repository_url:github.com/khustochka/kjogvi git.commit.sha:${GIT_REVISION}"

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
