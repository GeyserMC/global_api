FROM elixir:1.12.2 as build

# prepare build dir
WORKDIR /app

ENV NODE_VERSION=16 \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.50.0

# install nodejs and rust
RUN curl -sL https://deb.nodesource.com/setup_$NODE_VERSION.x | bash - && \
  apt-get install -y nodejs

RUN curl https://sh.rustup.rs -sSf > rustup.sh
RUN chmod +x rustup.sh
RUN ./rustup.sh -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION
RUN chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force

ENV MIX_ENV=prod

# download and build mix dependencies
COPY mix.exs mix.lock ./
COPY config config
COPY native native
RUN mix do deps.get --only $MIX_ENV, deps.compile

#
# todo make sure that we don't override the config files, because we also don't want to upload the secrets to github
#

# install node dependencies
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error

# copy our code so that it can be used for building our assets
COPY lib lib

# build assets
COPY priv priv
COPY assets assets
RUN npm run --prefix ./assets deploy
RUN mix phx.digest

# build release
COPY rel rel
RUN mix distillery.release

FROM scratch as app

ARG APP_NAME \
    APP_VSN

WORKDIR /app

COPY mix.exs ./

COPY --from=build /app/_build/prod/rel/$APP_NAME/releases/$APP_VSN/$APP_NAME.tar.gz ./$APP_NAME-$APP_VSN.tar.gz

CMD ["/bin/bash"]