defmodule Clawbreaker.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/CloudBedrock/clawbreaker"

  def project do
    [
      app: :clawbreaker,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      aliases: aliases(),
      description: "Official Elixir client for Clawbreaker AI agent platform",
      name: "Clawbreaker",
      source_url: @source_url,
      homepage_url: "https://clawbreaker.ai",

      # Dialyzer
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Clawbreaker.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # HTTP client
      {:req, "~> 0.5"},

      # JSON
      {:jason, "~> 1.4"},

      # Livebook smart cells
      {:kino, "~> 0.14", optional: true},

      # Dev/test
      {:ex_doc, "~> 0.31", only: [:dev, :test], runtime: false},
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
        "Website" => "https://clawbreaker.ai",
        "Documentation" => "https://hexdocs.pm/clawbreaker",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "Clawbreaker",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: "https://clawbreaker.ai",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        Core: [
          Clawbreaker,
          Clawbreaker.Agent
        ],
        Errors: [
          Clawbreaker.ConnectionError,
          Clawbreaker.APIError
        ]
      ]
    ]
  end

  defp aliases do
    [
      lint: ["format --check-formatted", "credo --strict"],
      ci: ["lint", "test", "dialyzer"]
    ]
  end
end
