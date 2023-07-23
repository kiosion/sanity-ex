defmodule SanityEx.HTTPClient do
  @moduledoc false

  @callback get(String.t(), headers :: list()) ::
              {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
  @callback post(String.t(), headers :: list(), body :: map()) ::
              {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
end
