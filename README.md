# GlobalLinking

Run the following queries on your database:
```mysql
CREATE TABLE IF NOT EXISTS `links`
(
    `bedrockId`      BIGINT,
    `javaId`         VARCHAR(36),
    `javaName`       VARCHAR(16),
    `lastNameUpdate` TIMESTAMP DEFAULT UTC_TIMESTAMP(),
    PRIMARY KEY (`bedrockId`)
);

CREATE TABLE IF NOT EXISTS `skins`
(
    `bedrockId`      BIGINT,
    `textureId`      VARCHAR(64),
    `lastUpdate` TIMESTAMP DEFAULT UTC_TIMESTAMP(),
    PRIMARY KEY (`bedrockId`)
);
```

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
