FROM elixir:1.14 AS base

ARG MIX_ENV

WORKDIR /app

ENV NODE_VERSION=18 \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.64.0

RUN curl -sL https://deb.nodesource.com/setup_$NODE_VERSION.x | bash - && \
  apt-get install -y nodejs

RUN curl https://sh.rustup.rs -sSf > rustup.sh
RUN chmod +x rustup.sh
RUN ./rustup.sh -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION
RUN chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force

ENV MIX_ENV=${MIX_ENV:-prod}

COPY mix.exs mix.lock ./
COPY assets/package.json assets/package-lock.json ./assets/
RUN mix deps.get
RUN cd assets && npm i && cd ../

# can't use single command as it'd copy all the dirs their content in one folder :/
COPY config config
COPY native native
COPY lib lib
COPY priv priv
COPY assets assets


FROM base AS dev
#todo


FROM debian:bullseye AS prod
#todo use the release and run it


FROM base AS release_build

RUN mix assets.deploy

COPY rel rel
RUN mix distillery.release


FROM scratch AS release

ARG APP_NAME \
    APP_VSN

# if this fails, check if APP_NAME & APP_VSN are defined
COPY --from=release_build /app/_build/prod/rel/${APP_NAME}/releases/${APP_VSN}/${APP_NAME}.tar.gz ./${APP_NAME}-${APP_VSN}.tar.gz

CMD ["/bin/bash"]