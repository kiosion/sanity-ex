defmodule SanityEx.Client do
  @moduledoc """
  `SanityEx.Client` is used for interactions with the Sanity HTTP API.

  It provides an interface for making queries, sending patches, and constructing URLs for asset IDs.
  """

  use GenServer

  require Jason

  @doc """
  Starts the client with the given options.

  This function is typically called when your application starts.

  ## Options

  * `:project_id` - The project ID for your Sanity project
  * `:api_version` - The dated version of the Sanity API to use.
  * `:token` - The API token for making authorized requests.

  The following are optional:
  * `:dataset` - The dataset to query against. Defaults to `production`.
  * `:asset_url` - The base asset URL to use. Defaults to `cdn.sanity.io/images/{project_id}/{dataset}/`.

  ## Examples

      iex> SanityEx.Client.start_link([
          project_id: "your_project_id",
          api_version: "v2021-06-07",
          dataset: "dev",
          token: "your_token"
        ])
      {:ok, %{ ... }}

  """
  @spec start_link(Keyword.t()) :: {:ok, pid()} | {:error, any()}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec init(Keyword.t()) :: {:ok, map()}
  def init(opts) do
    project_id = Keyword.get(opts, :project_id)
    api_version = Keyword.get(opts, :api_version)
    dataset = Keyword.get(opts, :dataset, "production")

    asset_url =
      Keyword.get(opts, :asset_url, "https://cdn.sanity.io/images/#{project_id}/#{dataset}/")

    token = Keyword.get(opts, :token)

    state = %{
      :project_id => project_id,
      :dataset => dataset,
      :api_version => api_version,
      :asset_url => asset_url,
      :token => token
    }

    {:ok, state}
  end

  defp get_headers(token) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{token}"},
      {"Accept", "application/json"}
    ]
  end

  defp is_valid_query?(query) do
    case is_binary(query) and String.trim(query) != "" do
      true -> {:ok, query}
      _ -> {:error, :invalid_query}
    end
  end

  defp is_valid_asset?(asset_id) do
    case is_binary(asset_id) and String.trim(asset_id) != "" do
      true -> {:ok, asset_id}
      _ -> {:error, :invalid_asset}
    end
  end

  defp is_valid_url?(url) do
    url
    |> URI.parse()
    |> Map.get(:scheme)
    |> case do
      nil -> {:error, :invalid_url}
      _ -> {:ok, url}
    end
  end

  defp construct_query_url(state, query, api_cdn) do
    api =
      case api_cdn do
        true -> "api"
        false -> "apicdn"
      end

    [
      "https://",
      to_string(state[:project_id]),
      ".",
      api,
      ".sanity.io/",
      to_string(state[:api_version]),
      "/data/query/",
      to_string(state[:dataset]),
      "/?",
      URI.encode_query(%{"query" => query})
    ]
    |> Enum.join()
  end

  @doc """
  Executes a GROQ query against the Sanity API.

  Takes a GROQ query as a string and sends it to the Sanity API, returning the body of the response as a string,
  or an error tuple on failure.

  ## Params

  * `query_str` - The GROQ query string to be executed.
  * `api_cdn` - Query against Sanity's CDN for faster response times - defaults to true if not specified

  ## Examples

      iex> SanityEx.Client.query("*[_type == 'post']{title, slug, _id}")
      {:ok, sanity_response} | {:error, {:sanity_error, status_code, message}} | {:error, {:fetch_error, message}} | {:error, {:params, message}}

  """
  @spec query(String.t(), boolean()) ::
          {:ok, String.t()}
          | {:error, {:sanity_error, integer(), String.t()}}
          | {:error, {:fetch_error, String.t()}}
          | {:error, {:params, String.t()}}
  def query(query_str, api_cdn \\ true),
    do: GenServer.call(__MODULE__, {:fetch, query_str, api_cdn})

  @doc """
  Executes multiple GROQ queries against the Sanity API asynchronously.

  Takes a list of GROQ queries as strings and sends them to the Sanity API.
  Each query is executed in a separate process. All queries are waited on and returned as a list.
  Each result is a tuple, where the first element is the query and the second is its result.

  ## Params

    - `queries`: A list of GROQ queries as strings
    - `api_cdn`: Query against Sanity's CDN for faster response times - defaults to true if not specified

  ## Returns

  A list of tuples where the first element is the query string and the second element is the result of that query.
  The result of a query is the body of the response as a string on success, or an error tuple on failure.

  ## Examples

      iex> SanityEx.Client.query_async(["*[_type == 'post']{title, slug, _id}", "*[_type == 'author']{name, _id}"])
      [
        {"*[_type == 'post']{title, slug, _id}", {:ok, sanity_response1}},
        {"*[_type == 'author']{name, _id}", {:ok, sanity_response2}}
      ]

  """
  @spec query_async([String.t()], boolean()) :: [
          {String.t(), {:ok, String.t()} | {:error, any()}}
        ]
  def query_async(queries, api_cdn \\ true) do
    queries
    |> Enum.map(&Task.async(fn -> {&1, GenServer.call(__MODULE__, {:fetch, &1, api_cdn})} end))
    |> Enum.map(&Task.await/1)
  end

  @doc """
  Constructs a CDN URL for a given Sanity asset ID.

  Takes an asset ID and optional query parameters map, and returns the constructed URL as a string.
  It returns `{:ok, url}` on success, or an error tuple on failure.

  ## Params

  * `asset_id` - The ID of the asset for which the URL should be constructed.
  * `query_params` - Optional query parameters map to be appended to the URL.

  ## Examples

      iex> SanityEx.Client.url_for("image-asset-id")
      {:ok, "https://cdn.sanity.io/images/..."}

      iex> SanityEx.Client.url_for("image-asset-id", %{w: 100, h: 100})
      {:ok, "https://cdn.sanity.io/images/...?w=100&h=100"}

  """
  @spec url_for(String.t(), map() | String.t()) ::
          {:ok, String.t()} | {:error, {:params, String.t()}}
  def url_for(asset_id, query_params \\ %{}),
    do: GenServer.call(__MODULE__, {:url_for, asset_id, query_params})

  @doc """
  Executes a list of patches on the Sanity API.

  This function takes a list of patches and sends them to the Sanity API as a single transaction.
  Each patch should be a map that defines an operation on a document.

  ## Params

    - `patches`: A list of patches. Each patch is a map that defines an operation on a document.

  ## Returns

  The function returns the body of the response as a string on success, or an error tuple on failure.

  ## Examples

      iex> SanityEx.Client.patch([
        %{
          "patch" => %{
            "id" => "person-1234",
            "set" => %{"name" => "Remington Steele"}
          }
        },
        %{
          "patch" => %{
            "id" => "remingtons",
            "insert" => %{
              "after" => "people[-1]",
              "items" => [
                %{
                  "_type" => "reference",
                  "_ref" => "person-1234"
                }
              ]
            }
          }
        }
      ])

  """
  @spec patch(list(map())) :: {:ok, String.t()} | {:error, any()}
  def patch(patches) do
    GenServer.call(__MODULE__, {:patch, patches})
  end

  def handle_call({:fetch, query, api_cdn}, _from, state) do
    http_client = Application.get_env(:sanity_ex, :http_client, SanityEx.DefaultHTTPClient)

    with {:ok, query} <- is_valid_query?(query),
         {:ok, url} <- is_valid_url?(construct_query_url(state, query, api_cdn)),
         headers <- get_headers(state[:token]) do
      case http_client.get(url, headers) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          {:reply, {:ok, body}, state}

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          {:reply, {:error, {:sanity_error, status_code, body}}, state}

        {:error, %HTTPoison.Error{reason: reason}} ->
          {:reply, {:error, {:fetch_error, reason}}, state}

        _ ->
          {:reply, {:error, {:fetch_error, "Unknown error occured during request"}}, state}
      end
    else
      {:error, :invalid_query} ->
        {:reply, {:error, {:params, "Query must be a non-empty string"}}, state}

      {:error, :invalid_url} ->
        {:reply, {:error, {:params, "Query URL must be a valid URL"}}, state}
    end
  end

  def handle_call({:url_for, asset_id, query_params}, _from, state) do
    with {:ok, asset_id} <- is_valid_asset?(asset_id),
         {:ok, url} <- is_valid_url?(state[:asset_url] <> asset_id) do
      case query_params do
        %{} ->
          {:reply, {:ok, url}, state}

        params when is_binary(params) ->
          {:reply, {:ok, url <> "?" <> params}, state}

        _ ->
          {:reply, {:ok, url <> "?" <> URI.encode_query(query_params)}, state}
      end
    else
      {:error, :invalid_asset} ->
        {:reply, {:error, {:params, "Asset ID must be a non-empty string"}}, state}

      {:error, :invalid_url} ->
        {:reply, {:error, {:params, "Asset URL must be a valid URL"}}, state}
    end
  end

  def handle_call({:patch, patches}, _from, state) do
    http_client = Application.get_env(:sanity_ex, :http_client, SanityEx.DefaultHTTPClient)

    with {:ok, url} <- is_valid_url?(state[:query_url]),
         headers <- get_headers(state[:token]),
         payload <- Jason.encode(%{"mutations" => patches}) do
      case http_client.post(url, payload, headers) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          {:reply, {:ok, body}, state}

        {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
          {:reply, {:error, {:sanity_error, status_code, body}}, state}

        {:error, %HTTPoison.Error{reason: reason}} ->
          {:reply, {:error, {:fetch_error, reason}}, state}

        _ ->
          {:reply, {:error, {:fetch_error, "Unknown error occurred during request"}}, state}
      end
    else
      {:error, :invalid_url} ->
        {:reply, {:error, {:params, "Query URL must be a valid URL"}}, state}
    end
  end
end
