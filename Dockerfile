FROM elixir:1.13.4-otp-25 AS build

ARG MIX_ENV

WORKDIR /app

ENV NODE_VERSION=18 \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.63.0

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
RUN mix deps_and_assets.get

ARG APP_NAME \
    APP_VSN

WORKDIR /app

COPY config native lib priv assets ./

RUN mix assets.deploy

COPY rel rel
RUN mix distillery.release

COPY --from=base /app/_build/prod/rel/${APP_NAME}/releases/${APP_VSN}/${APP_NAME}.tar.gz ./${APP_NAME}-${APP_VSN}.tar.gz

CMD ["/bin/bash"]