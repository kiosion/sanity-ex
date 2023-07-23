defmodule SanityEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :sanity_ex,
      name: "SanityEx",
      version: "0.1.0",
      elixir: "~> 1.14",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      source_url: "https://github.com/kiosion/sanity-ex",
      docs: [
        main: "SanityEx",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    []
  end

  defp package do
    [
      files: ~w(lib mix.exs README* LICENSE* .formatter.exs),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/kiosion/sanity-ex"}
    ]
  end

  defp description do
    "A client for interacting with the Sanity API and constructing GROQ queries from Elixir applications."
  end

  defp deps do
    [
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
      {:httpoison, "~> 1.8"},
      {:jason, "~> 1.2"},
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
