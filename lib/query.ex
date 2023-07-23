defmodule SanityEx.Query do
  @moduledoc """
  `SanityEx.Query` is used for constructing GROQ queries from Elixir syntax.

  ## Example
      iex> Query.new()
        |> Query.filter(%{"_type" => "'post'"})
        |> Query.project([
          "title",
          "body",
          %{
            "'author'" => [
              ["'_id'", ["author", "_id", :follow]],
              ["'_type'", ["author", "_type", :follow]],
              ["'name'", ["author", "name", :follow]],
              ["'slug'", ["author", "slug", :follow]],
              ["'image'", ["author", "image", :follow]]
            ]
          }
        ])
        |> Query.slice(0)
        |> Query.build()
      "*[!(_id in path('drafts.**')) && _type == 'post']{title, body, 'author':{'_id':author->_id, '_type':author->_type, 'name':author->name, 'slug':author->slug, 'image':author->image}}[0]"
  """

  alias __MODULE__

  defstruct [
    :base_query,
    :filters,
    :projections,
    :order,
    :slice
  ]

  @type t :: %__MODULE__{
          base_query: String.t(),
          filters: list(),
          projections: list(),
          order: list(),
          slice: nil | integer() | String.t() | {integer(), integer()}
        }

  @doc """
  Initialize the building of a GROQ query pipeline. Returns a SanityEx.Query struct representing a GROQ query.

  ## Options
    - `:include_drafts` - If set, the query will include draft documents.
    - `:base_query` - If set, the query will use this as its basis instead of `*`.
  """
  @doc since: "0.1.0"
  @spec new(Keyword.t()) :: t()
  def new(opts \\ []) do
    include_drafts = Keyword.get(opts, :include_drafts, false)
    base_query = Keyword.get(opts, :base_query, "*")

    filters =
      if include_drafts or base_query == "" do
        []
      else
        [%{"_id" => ["in", "path('drafts.**')", :negate]}]
      end

    %Query{
      base_query: base_query,
      filters: filters,
      projections: [],
      order: [],
      slice: nil
    }
  end

  @doc """
  Add a filter to the query. The filter retains documents for which the expression evaluates to true.

  In a GROQ query, the Filter expression is the first expression in the query, and is wrapped in square brackets.

  ## Example
  ```elixir
    filter(query, [ %{ "_type" => "'post'" }, [{ "_id" => "'id'" }, { "slug.current" => "'slug'" }, { :join => "||" }] ])
    # => *[_type == 'post' && (_id == 'id' || slug.current == 'slug')]
  ```

  Read more about [filtering queries](https://www.sanity.io/docs/query-cheat-sheet#3949cadc7524)
  """
  @doc since: "0.1.0"
  @spec filter(Query.t(), maybe_improper_list() | map()) ::
          {:error, String.t(), Query.t()} | Query.t()
  def filter(%Query{} = template, [key, val]) when not is_map(key) and not is_map(val) do
    filter(template, [%{key => val}])
  end

  def filter(%Query{} = template, filter) when is_map(filter) do
    filter(template, [filter])
  end

  def filter(%Query{} = template, filters) when is_list(filters) do
    if filters_valid?(filters) do
      %{template | filters: template.filters ++ filters}
    else
      {:error, "Filters must be a list of maps or nested lists of maps", template}
    end
  end

  def filter({:error, reason, template}, _filter) do
    {:error, reason, template}
  end

  defp filters_valid?(filters) do
    Enum.all?(filters, fn
      filter when is_map(filter) -> true
      filter when is_list(filter) -> filters_valid?(filter)
      _ -> false
    end)
  end

  @doc """
  Adds object projection(s) to the query. This determines how the results of the query should be formatted.

  ## Example
  ```elixir
    project(query, ["_id", ["'objectID'", "_id"], "_rev", "_type", "title", ... ])
    # => *[_type == 'post']{_id, 'objectID':_id, _rev, _type, title, ... }
  ```

  In order to Join certain attributes inside a projection, you can use a nested map with the `:follow` atom present:
  ```elixir
    project(
      query,
      [
        "_id",
        %{
          "'author'" => [
            ["'_id'", ["author", "_id", :follow]]
          ]
        }
      ]
    )
    # => *[_type == 'post']{_id, 'author':{'_id':author->_id}}
  ```

  Read more about [object projections](https://www.sanity.io/docs/query-cheat-sheet#55d30f6804cc)
  """
  @doc since: "0.1.0"
  @spec project(Query.t(), any) ::
          {:error, String.t(), Query.t()} | Query.t()
  def project(%Query{} = template, projections) do
    case projections do
      projections when is_list(projections) ->
        %{template | projections: template.projections ++ projections}

      projection when is_map(projection) or is_binary(projection) ->
        %{template | projections: template.projections ++ [projection]}

      _ ->
        {:error, "Projections must be a string, list of strings, or nested maps", template}
    end
  end

  def project({:error, reason, template}, _projection) do
    {:error, reason, template}
  end

  @doc """
  Specify the ordering of the results of the query.

  ## Example
  ```elixir
    order(query, "_createdAt desc")
    # or, equivalently:
    order(query, ["_createdAt", "desc"])
    # => *[_type == 'post'] | order(_createdAt desc)
  ```

  The examples above order the query results by the `_createdAt` attribute in descending order.

  Read more about [ordering results](https://www.sanity.io/docs/query-cheat-sheet#b5aec96cf56c)
  """
  @doc since: "0.1.0"
  @spec order(Query.t(), integer() | String.t() | maybe_improper_list()) ::
          {:error, String.t(), Query.t()} | Query.t()
  def order(%Query{} = template, order) do
    case order do
      order when is_binary(order) ->
        %{template | order: [order]}

      order when is_list(order) ->
        %{template | order: order}

      _ ->
        {:error, "Order must be a string or a list of strings", template}
    end
  end

  def order({:error, reason, template}, _order) do
    {:error, reason, template}
  end

  @doc """
  Slice the results returned by the query, or access a specific index.

  ## Example
  ```elixir
    slice(query, {0, 5})
    # => *[_type == 'post'][0...5]
    slice(query, 0)
    # => *[_type == 'post'][0]
  ```

  The first example above limits the query results to a maximum of 5 documents, starting at index 0. The second returns only the first index of the query results.

  Read more about [slicing query results](https://www.sanity.io/docs/query-cheat-sheet#aa94b64a5bf5)
  """
  @doc since: "0.1.0"
  @spec slice(Query.t(), integer() | String.t() | {integer(), integer()}) ::
          {:error, String.t(), Query.t()} | Query.t()
  def slice(%Query{} = template, slice) do
    case slice do
      {offset, limit}
      when is_integer(offset) and is_integer(limit) and offset >= 0 and limit > 0 ->
        %{template | slice: {offset, limit}}

      {offset, limit}
      when is_integer(offset) and is_integer(limit) and offset == 0 and limit == 0 ->
        template

      slice when (is_integer(slice) and slice >= 0) or is_binary(slice) ->
        %{template | slice: slice}

      _ ->
        {:error,
         "Slice must be a positive integer, a binary, or a tuple of {offset, limit} where both are positive integers",
         template}
    end
  end

  def slice({:error, reason, template}, _slice) do
    {:error, reason, template}
  end

  @doc """
  Builds a GROQ query from the given structure.

  The final query is returned as a string.
  """
  @doc since: "0.1.0"
  @spec build(Query.t()) :: {:error, String.t(), Query.t()} | String.t()
  def build(%Query{
        base_query: base_query,
        filters: filters,
        projections: projections,
        order: order,
        slice: slice
      }) do
    base_query
    |> build_filters(filters)
    |> build_projections(projections)
    |> build_order(order)
    |> build_slice(slice)
  end

  def build({:error, reason, template}) do
    {:error, reason, template}
  end

  @doc """
  Builds a GROQ query from the given structure.

  The final query is returned as a string, or an error is raised if the query could not be built.
  """
  @doc since: "0.1.0"
  @spec build!(Query.t()) :: String.t()
  def build!(query) do
    case build(query) do
      {:error, reason, _} -> raise reason
      query_str -> query_str
    end
  end

  defp build_filters(query_str, filters) do
    filters_string =
      filters
      |> Enum.map(&format_filter!/1)
      |> Enum.join(" && ")

    case filters_string do
      "" -> query_str
      _ -> query_str <> "[#{filters_string}]"
    end
  end

  defp format_filter!(filter) do
    case filter do
      %{} ->
        Enum.map(Enum.filter(filter, fn {key, _} -> is_binary(key) end), fn {key, value} ->
          nest = Map.get(filter, :nest, false)

          case nest do
            true ->
              key <> "(" <> format_filter!(value <> ")")

            _ ->
              format_filter_pair(key, value)
          end
        end)

      {key, value} when is_binary(key) and is_binary(value) ->
        format_filter_pair(key, value)

      filters when is_list(filters) ->
        join =
          Enum.find(filters, fn x -> is_map(x) && Map.get(x, :join) end)
          |> (fn x ->
                if x do
                  Map.get(x, :join)
                else
                  "||"
                end
              end).()

        negate =
          Enum.find(filters, fn x -> is_map(x) && Map.get(x, :negate) end)
          |> (fn x ->
                if x do
                  "!"
                else
                  ""
                end
              end).()

        filters =
          Enum.reject(filters, fn x -> is_map(x) && (Map.get(x, :join) || Map.get(x, :negate)) end)

        negate <> "(#{Enum.map(filters, &format_filter!/1) |> Enum.join(" " <> join <> " ")})"

      filter when is_binary(filter) ->
        filter

      filter ->
        raise "Invalid filter format: #{inspect(filter)}"
    end
  end

  defp format_filter_pair(key, value) do
    key =
      case key do
        key when is_atom(key) -> Atom.to_string(key)
        _ -> key
      end

    case value do
      [operator, value | opts] when is_binary(operator) and is_binary(value) ->
        negate = Enum.any?(opts, fn opt -> opt == :negate end)

        case negate do
          true ->
            "!(#{key} #{operator} #{value})"

          false ->
            "#{key} #{operator} #{value}"
        end

      [operator, value] when is_binary(operator) and is_binary(value) ->
        "#{key} #{operator} #{value}"

      _ ->
        "#{key} == #{value}"
    end
  end

  defp build_projections(query, projections) do
    query_length = String.length(query)

    case projections do
      nil ->
        query

      [] ->
        query

      # If only one projection is provided, don't wrap it in curly braces, as it can be a direct property access of the filter
      # However, only do this if filters are present, as otherwise it's a direct query (e.g. query length > 1)
      # This should also not occur if the projection contains nested projections - in that case, it should always be joined and wrapped
      [projection] when query_length > 1 and is_binary(projection) ->
        query <> ".#{projection}"

      _ ->
        query <> "{#{join_projections(projections)}}"
    end
  end

  defp join_projections(projections) do
    Enum.join(
      projections
      |> Enum.map(&format_projection/1),
      ", "
    )
  end

  defp format_projection(projection) when is_map(projection) do
    joiner = if Map.get(projection, :join, false), do: Map.get(projection, :join), else: ":"

    Enum.join(
      Enum.map(Enum.filter(projection, fn {key, _} -> is_binary(key) end), fn {key, value} ->
        "#{key}#{joiner}{#{join_projections(value)}}"
      end),
      ", "
    )
  end

  defp format_projection([key, value]) do
    case value do
      value when is_list(value) ->
        "#{key}:#{format_projection(value)}"

      _ ->
        "#{key}:#{value}"
    end
  end

  defp format_projection([key, value, opt]) do
    joiner = if opt == :follow, do: "->", else: ":"

    case value do
      value when is_list(value) ->
        "#{key}#{joiner}{#{join_projections(value)}}"

      _ ->
        "#{key}#{joiner}#{value}"
    end
  end

  defp format_projection(projection) do
    projection
  end

  defp build_order(query_str, order) do
    case order do
      [] ->
        query_str

      _ ->
        query_str <> " | order(#{Enum.join(order, ", ")})"
    end
  end

  defp build_slice(query_str, slice) do
    case slice do
      nil ->
        query_str

      {offset, limit} ->
        query_str <> " [#{offset}...#{offset + limit}]"

      slice when is_binary(slice) or is_integer(slice) ->
        query_str <> "[#{slice}]"

      _ ->
        query_str
    end
  end
end
