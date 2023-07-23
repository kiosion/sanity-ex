# SanityEx

A client for interacting with the Sanity API and constructing GROQ queries from Elixir applications.

This is a very primitive implementation, built mostly for practice & my own use, and only supports _some_ of GROQ's syntax. Please feel free to contribute!

## Installation

Add `sanity_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
[
  {:sanity_ex, "~> 0.1.0"}
]
```

and run `$ mix deps.get`.

## Usage

Add the Client to your supervision tree:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      {
        SanityEx.Client,
        project_id: "your_project_id",
        dataset: "production",
        api_version: "v2021-03-25",
        token: "your_token"
      }
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

Then you can use the Client to interact with the Sanity API:

```elixir
SanityEx.Client.query("*[_type == 'movie']{title, releaseYear}")
```

### Options

The following options are required when configuring the client:

- `project_id` - The project ID for your Sanity project.
- `api_version` - The dated version of the Sanity API to use.
- `token` - The API token for making authorized requests.

The following are optional:
- `dataset` - The dataset to query against. Defaults to `production`.
- `asset_url` - The base asset URL to use. Defaults to `cdn.sanity.io/images/{project_id}/{dataset}/`.

## Documentation

Documentation can be found at [https://hexdocs.pm/sanity_ex](https://hexdocs.pm/sanity_ex).
