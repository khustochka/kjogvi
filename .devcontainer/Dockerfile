ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.3
ARG DEBIAN_VERSION=bookworm-20250224-slim
ARG DISTRO_VERSION=debian-${DEBIAN_VERSION}

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-${DISTRO_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE}

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential ssh git \
    # for development
    inotify-tools \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN mix local.hex --force

# [Optional] Uncomment this section to install additional OS packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends git ssh \
#     # to install firefox
#     software-properties-common python3-launchpadlib \
#     build-essential libpq-dev wget curl gzip \
#     xz-utils libsqlite3-dev libssl-dev libyaml-dev

# [Optional] Uncomment this line to install global node packages.
# RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g <your-package-here>" 2>&1

# ARG NODE_VERSION=18.17.0
# ARG YARN_VERSION=1.22.19
# RUN curl https://get.volta.sh | bash
# ENV VOLTA_HOME /root/.volta
# ENV PATH $VOLTA_HOME/bin:/usr/local/bin:$PATH
# RUN volta install node@${NODE_VERSION} yarn@${YARN_VERSION}
