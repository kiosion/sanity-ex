defmodule SanityExQueryTest do
  use ExUnit.Case, async: true

  alias SanityEx.Query

  test "Query module bubbles error through pipe" do
    result =
      Query.new()
      |> Query.filter([
        %{"_type" => "'post'"},
        [
          %{"_id" => "'some_id'"},
          %{"slug.current" => "'some_other_id'"},
          %{:join => "||"}
        ]
      ])
      |> Query.project(0)
      |> Query.qualify("[0]")
      |> Query.build()

    assert {:error, "Projections must be a list of strings or nested maps",
            %Query{
              base_query: "*",
              filters: [
                %{"_id" => ["in", "path('drafts.**')", :negate]},
                %{"_type" => "'post'"},
                [%{"_id" => "'some_id'"}, %{"slug.current" => "'some_other_id'"}, %{join: "||"}]
              ],
              projections: [],
              scope_qualifier: "",
              order: [],
              limit: 0
            }} == result
  end

  test "Query.build! raises bubbled errors" do
    try do
      Query.new()
      |> Query.filter([
        %{"_type" => "'post'"},
        [
          %{"_id" => "'some_id'"},
          %{"slug.current" => "'some_other_id'"},
          %{:join => "||"}
        ]
      ])
      |> Query.project(0)
      |> Query.qualify("[0]")
      |> Query.build!()

      flunk("Should have raised error")
    rescue
      e in RuntimeError ->
        assert "Projections must be a list of strings or nested maps" == e.message
    end
  end

  test "Query module successfully constructs queries" do
    query =
      Query.new()
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

    assert "*[!(_id in path('drafts.**')) && _type == 'post']{title, body, 'author':{'_id':author->_id, '_type':author->_type, 'name':author->name, 'slug':author->slug, 'image':author->image}}[0]" ==
             query
  end
end
