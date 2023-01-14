FROM elixir:1.14.2 AS setup_base

WORKDIR /app

ENV NODE_VERSION=18 \
    RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.64.0

RUN curl -sL https://deb.nodesource.com/setup_$NODE_VERSION.x | bash - && \
  apt-get install -y nodejs

#todo ensure that Rust will always build with the x86_64 architecture
RUN curl https://sh.rustup.rs -sSf > rustup.sh
RUN chmod +x rustup.sh
RUN ./rustup.sh -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION
RUN chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force


FROM setup_base AS bake_release
ARG MIX_ENV

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY assets/package.json assets/package-lock.json ./assets/
RUN npm ci --prefix ./assets

COPY config/config.exs config/$MIX_ENV.exs config/
RUN mix deps.compile

COPY priv priv

COPY native native
COPY lib lib
COPY assets assets

RUN mix assets.deploy

COPY rel rel
RUN mix release

RUN apt install -y p7zip-full
RUN 7z a global_api.7z /app/_build/$MIX_ENV/rel/global_api


FROM scratch AS release

COPY --from=bake_release /app/global_api.7z .

CMD ["/bin/bash"]


FROM setup_base AS dev

RUN apt install -y inotify-tools

EXPOSE 80 443
CMD npm i --prefix ./assets && mix deps.get && mix ecto.migrate && mix phx.server


FROM debian:bullseye AS prod
#todo use the release and run it

CMD ["/bin/bash"]