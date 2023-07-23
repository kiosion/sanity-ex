defmodule SanityEx.Query do
  @moduledoc """
  `SanityEx.Query` is used for constructing GROQ queries from Elixir syntax.

  ## Example
      iex> query = Query.new()
      iex> query
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
        |> Query.qualify("[0]")
        |> Query.build()
      "*[!(_id in path('drafts.**')) && _type == 'post']{title, body, 'author':{'_id':author->_id, '_type':author->_type, 'name':author->name, 'slug':author->slug, 'image':author->image}}[0]"
  """

  alias __MODULE__

  defstruct [
    :base_query,
    :filters,
    :projections,
    :scope_qualifier,
    :order,
    :limit
  ]

  @type t :: %__MODULE__{
          base_query: String.t(),
          filters: list(),
          projections: list(),
          scope_qualifier: String.t(),
          order: list(),
          limit: integer() | {integer(), integer()}
        }

  @doc """
  Initialize the building of a GROQ query pipeline. Returns a SanityEx.Query struct representing a GROQ query.

  ## Options
    - `:include_drafts` - If set to `true`, the query will include draft documents.
    - `:base_query` - If set, the query will use this as its base instead of `*`.
  """
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
      scope_qualifier: "",
      order: [],
      limit: 0
    }
  end

  @doc """
  Add a filter to the query. The filter retains documents for which the expression evaluates to true.

  ## Example
    iex> filter(query, [ %{ "_type" => "'post'" }, [{ "_id" => "'id'" }, { "slug.current" => "'slug'" }, { :join => "||" }] ])
  """
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
  Adds projection(s) to the query. This determines how the results of the query should be formatted.

  ## Example
    iex> project(query, ["_id", ["'objectID'", "_id"], "_rev", "_type", "title", ... ])
  """
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
  Adds a scope qualifier to the query. Scope qualifiers allow identifiers to refer to different attributes in different contexts.

  ## Example
    iex> qualify(query, "[0]")
  """
  @spec qualify(Query.t(), any) ::
          {:error, String.t(), Query.t()} | Query.t()
  def qualify(%Query{} = template, key) do
    case key do
      key when is_binary(key) ->
        %{template | scope_qualifier: key}

      _ ->
        {:error, "Qualifier must be a string", template}
    end
  end

  def qualify({:error, reason, template}, _key) do
    {:error, reason, template}
  end

  @doc """
  Specify the ordering of the results of the query.

  ## Example
    iex> set_order(query, "_createdAt desc")
    iex> set_order(query, ["_createdAt", "desc"])

  The example above orders the query results by the `_createdAt` attribute in descending order.
  """
  @spec set_order(Query.t(), integer() | String.t() | maybe_improper_list()) ::
          {:error, String.t(), Query.t()} | Query.t()
  def set_order(%Query{} = template, order) do
    case order do
      order when is_binary(order) ->
        %{template | order: [order]}

      order when is_list(order) ->
        %{template | order: order}

      _ ->
        {:error, "Order must be a string or a list of strings", template}
    end
  end

  def set_order({:error, reason, template}, _order) do
    {:error, reason, template}
  end

  @doc """
  Set the limit of the number of results the query should return.

  ## Example
    iex> set_limit(query, 5)

  The example above limits the query results to a maximum of 5 documents.
  """
  @spec set_limit(Query.t(), integer() | {integer(), integer()}) ::
          {:error, String.t(), Query.t()} | Query.t()
  def set_limit(%Query{} = template, limit) do
    case limit do
      {offset, limit}
      when is_integer(offset) and is_integer(limit) and offset >= 0 and limit > 0 ->
        %{template | limit: {offset, limit}}

      limit when is_integer(limit) and limit > 0 ->
        %{template | limit: limit}

      {offset, limit}
      when is_integer(offset) and is_integer(limit) and offset == 0 and limit == 0 ->
        template

      limit when is_integer(limit) and limit == 0 ->
        template

      _ ->
        {:error,
         "Limit must be a positive integer or a tuple of {offset, limit} where both are > 0",
         template}
    end
  end

  def set_limit({:error, reason, template}, _limit) do
    {:error, reason, template}
  end

  @doc """
  Builds a GROQ query from the given structure.

  The final query is returned as a string.
  """
  @spec build(query :: t()) :: {:error, String.t(), Query.t()} | String.t()
  def build(%Query{
        base_query: base_query,
        filters: filters,
        projections: projections,
        scope_qualifier: qualifier,
        order: order,
        limit: limit
      }) do
    base_query
    |> build_filters(filters)
    |> build_projections(projections)
    |> build_qualifier(qualifier)
    |> build_order(order)
    |> build_limit(limit)
  end

  def build({:error, reason, template}) do
    {:error, reason, template}
  end

  @doc """
  Builds a GROQ query from the given structure.

  The final query is returned as a string, or an error is raised if the query could not be built.
  """
  @spec build!(Query.t()) :: String.t()
  def build!(query) do
    case build(query) do
      {:error, reason, _} -> raise reason
      query_str -> query_str
    end
  end

  defp build_qualifier(query_str, qualifier) do
    case qualifier do
      qualifier when is_binary(qualifier) and qualifier != "" ->
        query_str <> qualifier

      _ ->
        query_str
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

  defp build_limit(query_str, limit) do
    case limit do
      0 ->
        query_str

      {offset, limit} ->
        query_str <> " [#{offset}...#{offset + limit}]"

      limit when is_binary(limit) or is_integer(limit) ->
        query_str <> " [0...#{limit}]"

      _ ->
        query_str
    end
  end
end
