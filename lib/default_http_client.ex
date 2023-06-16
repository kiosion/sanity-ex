defmodule SanityEx.DefaultHTTPClient do
  @behaviour SanityEx.HTTPClient

  def get(url, headers) do
    HTTPoison.get(url, headers)
  end

  def post(url, headers, body) do
    HTTPoison.post(url, body, headers)
  end
end
