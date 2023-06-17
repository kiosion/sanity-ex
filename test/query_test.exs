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

    assert {:error, "Projections must be a string, list of strings, or nested maps",
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
        assert "Projections must be a string, list of strings, or nested maps" == e.message
    end
  end

  test "Query module successfully constructs queries" do
    query =
      Query.new()
      |> Query.filter(%{"_type" => "'post'"})
      |> Query.project([
        "title",
        "body"
      ])
      |> Query.qualify("[0]")
      |> Query.build()

    assert "*[!(_id in path('drafts.**')) && _type == 'post']{title, body}[0]" ==
             query
  end

  test "Query.project handles nested projections" do
    query =
      Query.new()
      |> Query.filter(%{"_type" => "'post'"})
      |> Query.project([
        %{
          "'author'" => [
            "'name'",
            "'slug'",
            "'image'"
          ]
        }
      ])
      |> Query.build()

    assert "*[!(_id in path('drafts.**')) && _type == 'post']{'author':{'name', 'slug', 'image'}}" ==
             query
  end

  test "Query.project handles following refs" do
    query =
      Query.new(include_drafts: true)
      |> Query.filter(%{"_type" => "'post'"})
      |> Query.project([
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
      |> Query.build()

    assert "*[_type == 'post']{'author':{'_id':author->_id, '_type':author->_type, 'name':author->name, 'slug':author->slug, 'image':author->image}}" ==
             query
  end

  test "Query.project handles direct property access from filters" do
    query =
      Query.new(include_drafts: true)
      |> Query.filter(%{"_id" => "'some_id'"})
      |> Query.project("title")
      |> Query.build()

    assert "*[_id == 'some_id'].title" == query
  end
end
