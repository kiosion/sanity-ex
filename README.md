# SanityEx

A client for interacting with the Sanity API and constructing GROQ queries from Elixir applications.

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

The following options are available when configuring the client:

- `project_id` - The project ID for your Sanity project
- `dataset` - The dataset to use for the API calls
- `api_version` - The API version to use
- `token` - The token to use for authentication
- `asset_url` - The URL to use for asset URLs (defaults to `cdn.sanity.io/images/{project_id}/{dataset}/`)

## Documentation

Documentation can be found at [https://hexdocs.pm/sanity_ex](https://hexdocs.pm/sanity_ex).
