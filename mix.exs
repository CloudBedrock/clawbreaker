defmodule Clawbreaker.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/CloudBedrock/clawbreaker"

  def project do
    [
      app: :clawbreaker,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      description: "Official Elixir client for Clawbreaker AI agent platform",
      name: "Clawbreaker",
      source_url: @source_url,
      homepage_url: "https://clawbreaker.dev"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Clawbreaker.Application, []}
    ]
  end

  defp deps do
    [
      # HTTP client
      {:req, "~> 0.5"},

      # JSON
      {:jason, "~> 1.4"},

      # Livebook smart cells
      {:kino, "~> 0.14", optional: true},

      # OAuth (for interactive auth)
      {:plug_cowboy, "~> 2.7", optional: true},

      # Dev/test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:mox, "~> 1.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      name: "clawbreaker",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["Apache-2.0"],
      links: %{
        "Website" => "https://clawbreaker.dev",
        "Documentation" => "https://docs.clawbreaker.dev"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}"
    ]
  end
end
