defmodule Clawbreaker do
  @moduledoc """
  Official Elixir client for Clawbreaker AI agent platform.

  ## Quick Start

      # In Livebook
      Mix.install([{:clawbreaker, "~> 0.1"}])

      # Connect (opens OAuth in browser)
      Clawbreaker.connect!()

      # Create and test an agent
      agent = Clawbreaker.Agent.create!(
        name: "My Bot",
        model: "claude-sonnet-4",
        system_prompt: "You are helpful."
      )

      Clawbreaker.Agent.test!(agent, "Hello!")

  ## Configuration

  Configure via application environment or at runtime:

      # config/runtime.exs
      config :clawbreaker,
        url: System.get_env("CLAWBREAKER_URL", "https://api.clawbreaker.dev"),
        api_key: System.get_env("CLAWBREAKER_API_KEY")

  Or connect at runtime:

      Clawbreaker.connect!(api_key: "sk_...")

  ## Smart Cells

  When used in Livebook, smart cells are automatically registered:

  - 🔌 **Connect to Clawbreaker** - OAuth/API key setup
  - 🤖 **Agent Builder** - Visual agent configuration
  - 💬 **Agent Chat** - Interactive testing
  - 🔧 **Tool Builder** - Create custom tools
  - 🚀 **Deploy Agent** - Push to staging/production
  - 📊 **Metrics** - Usage and cost visualization

  """

  alias Clawbreaker.{Config, Client}

  @doc """
  Connect to Clawbreaker with interactive OAuth flow.

  Opens a browser window for authentication. Credentials are stored
  locally for future sessions.

  ## Options

    * `:url` - Clawbreaker instance URL (default: `https://api.clawbreaker.dev`)
    * `:org` - Organization to connect to (if you belong to multiple)

  ## Examples

      # Connect to Clawbreaker Cloud
      Clawbreaker.connect!()

      # Connect to self-hosted instance
      Clawbreaker.connect!(url: "https://clawbreaker.mycompany.com")

  """
  def connect!(opts \\ []) do
    case connect(opts) do
      {:ok, config} -> config
      {:error, reason} -> raise Clawbreaker.ConnectionError, reason
    end
  end

  @doc """
  Connect to Clawbreaker. Returns `{:ok, config}` or `{:error, reason}`.

  See `connect!/1` for options.
  """
  def connect(opts \\ []) do
    url = opts[:url] || Config.default_url()

    cond do
      opts[:api_key] ->
        Config.configure(url: url, api_key: opts[:api_key])

      Config.has_stored_credentials?() ->
        Config.load_stored_credentials()

      true ->
        Clawbreaker.Auth.interactive_oauth(url, opts)
    end
  end

  @doc """
  Connect using environment variables.

  Expects:
    * `CLAWBREAKER_URL` (optional, defaults to cloud)
    * `CLAWBREAKER_API_KEY` (required)

  ## Examples

      Clawbreaker.connect_from_env!()

  """
  def connect_from_env! do
    url = System.get_env("CLAWBREAKER_URL", Config.default_url())

    case System.get_env("CLAWBREAKER_API_KEY") do
      nil ->
        raise Clawbreaker.ConnectionError, "CLAWBREAKER_API_KEY environment variable not set"

      api_key ->
        connect!(url: url, api_key: api_key)
    end
  end

  @doc """
  Check if connected to Clawbreaker.

  ## Examples

      Clawbreaker.connected?()
      #=> true

  """
  def connected? do
    Config.configured?()
  end

  @doc """
  Get current connection info.

  ## Examples

      Clawbreaker.whoami()
      #=> %{user: "jim@example.com", org: "acme-corp", url: "https://api.clawbreaker.dev"}

  """
  def whoami do
    Client.get!("/v1/whoami")
  end

  @doc """
  List organizations you belong to.

  ## Examples

      Clawbreaker.orgs()
      #=> [%{id: "acme-corp", name: "Acme Corporation", role: :admin}]

  """
  def orgs do
    Client.get!("/v1/orgs")
  end

  @doc """
  Disconnect and clear stored credentials.
  """
  def disconnect do
    Config.clear()
  end
end
