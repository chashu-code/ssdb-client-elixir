# SSDB

elixir SSDB client, adapted from https://github.com/kqqsysu/ssdb-erlang

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add ssdb to your list of dependencies in `mix.exs`:

        def deps do
          [{:ssdb, "~> 0.0.1"}]
        end

  2. Ensure ssdb is started before your application:

        def application do
          [applications: [:ssdb]]
        end

  3. Config ssdb in `config.exs`:

        config :ssdb,
          host: "127.0.0.1",
          port: 6380,
          pool_size: 5,
          password: nil,
          is_reconnect: true

## API

  SSDB.query ["del", "a"]
  # result: ["ok", "1"]

  SSDB.query ["errorcmd"]
  #["client_error", "Unknown Command: errorcmd"]