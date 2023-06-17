defmodule SanityExTest do
  use ExUnit.Case

  import Mox

  alias SanityEx.Client

  setup :verify_on_exit!
  setup :set_mox_global

  Mox.defmock(SanityEx.MockHTTPClient, for: SanityEx.HTTPClient)

  setup do
    Application.put_env(:sanityex, :http_client, SanityEx.MockHTTPClient)

    # Start the GenServer w/ some fake opts
    {:ok, pid} =
      Client.start_link(
        project_id: "123",
        dataset: "production",
        api_version: "v2021-06-07",
        token: "abc123",
        asset_url: "https://fakeasseturl.com"
      )

    on_exit(fn ->
      Process.exit(pid, :kill)
    end)

    {:ok, pid: pid}
  end

  test "Client.query fetches from Sanity API" do
    mock_response = %HTTPoison.Response{
      body: "{\"key\": \"value\"}",
      status_code: 200
    }

    SanityEx.MockHTTPClient
    |> expect(
      :get,
      fn url, _headers ->
        assert url == "https://123.api.sanity.io/v2021-06-07/data/query/production/?query=test",
               "Unexpected URL: #{url}"

        {:ok, mock_response}
      end
    )

    assert {:ok, "{\"key\": \"value\"}"} = SanityEx.Client.query("test"),
           "Query did not return expected response"
  end

  test "Sanity error responses are handled" do
    mock_response = %HTTPoison.Response{
      body: "{\"error\": \"error message\"}",
      status_code: 400
    }

    SanityEx.MockHTTPClient
    |> expect(
      :get,
      fn _url, _headers ->
        {:ok, mock_response}
      end
    )

    assert {:error, {:sanity_error, 400, "{\"error\": \"error message\"}"}} =
             SanityEx.Client.query("test"),
           "Query did not return expected response"
  end
end
