defmodule Clawbreaker do
  @moduledoc """
  Official Elixir client for the Clawbreaker AI agent platform.

  ## Quick Start

      # Connect with OAuth (opens browser)
      Clawbreaker.connect!()

      # Or use API key
      Clawbreaker.connect!(api_key: System.fetch_env!("CLAWBREAKER_API_KEY"))

      # Create and test an agent
      agent = Clawbreaker.Agent.create!(
        name: "My Bot",
        model: "claude-sonnet-4",
        system_prompt: "You are helpful."
      )

      Clawbreaker.Agent.test!(agent, "Hello!")

  ## Configuration

  Configure via application environment:

      # config/runtime.exs
      config :clawbreaker,
        url: System.get_env("CLAWBREAKER_URL", "https://api.clawbreaker.dev"),
        api_key: System.get_env("CLAWBREAKER_API_KEY")

  Or connect at runtime:

      Clawbreaker.connect!(url: "https://api.clawbreaker.dev", api_key: "sk_...")

  ## Livebook Smart Cells

  When used in Livebook, visual smart cells are automatically registered:

  - 🔌 **Connect to Clawbreaker** - OAuth/API key setup
  - 🤖 **Agent Builder** - Visual agent configuration
  - 💬 **Agent Chat** - Interactive testing with streaming
  - 🚀 **Deploy Agent** - One-click deployment
  """

  alias Clawbreaker.Config

  @type connect_opts :: [
          url: String.t(),
          api_key: String.t(),
          org: String.t(),
          persist: boolean()
        ]

  @type config :: %{url: String.t(), api_key: String.t() | nil, org: String.t() | nil}

  @doc """
  Connect to Clawbreaker with interactive OAuth flow.

  Opens a browser window for authentication. Credentials are stored
  locally in `~/.clawbreaker/credentials.json` for future sessions.

  ## Options

    * `:url` - Clawbreaker instance URL (default: `https://api.clawbreaker.dev`)
    * `:api_key` - API key for authentication (skips OAuth if provided)
    * `:org` - Organization to connect to (if you belong to multiple)
    * `:persist` - Whether to save credentials (default: `true`)

  ## Examples

      # Connect to Clawbreaker Cloud with OAuth
      Clawbreaker.connect!()

      # Connect with API key
      Clawbreaker.connect!(api_key: "sk_live_...")

      # Connect to self-hosted instance
      Clawbreaker.connect!(url: "https://clawbreaker.mycompany.com")

  """
  @spec connect!(connect_opts()) :: config()
  def connect!(opts \\ []) do
    case connect(opts) do
      {:ok, config} -> config
      {:error, reason} -> raise Clawbreaker.ConnectionError, reason
    end
  end

  @doc """
  Connect to Clawbreaker. Returns `{:ok, config}` or `{:error, reason}`.

  See `connect!/1` for options and examples.
  """
  @spec connect(connect_opts()) :: {:ok, config()} | {:error, term()}
  def connect(opts \\ []) do
    url = opts[:url] || Config.default_url()

    cond do
      opts[:api_key] ->
        Config.configure(url: url, api_key: opts[:api_key], persist: opts[:persist] != false)

      Config.has_stored_credentials?() ->
        Config.load_stored_credentials()

      true ->
        Clawbreaker.Auth.interactive_oauth(url, opts)
    end
  end

  @doc """
  Connect using environment variables.

  Reads from:
    * `CLAWBREAKER_URL` - Instance URL (optional, defaults to cloud)
    * `CLAWBREAKER_API_KEY` - API key (required)

  ## Examples

      # Set env vars first:
      # export CLAWBREAKER_API_KEY=sk_live_...

      Clawbreaker.connect_from_env!()

  """
  @spec connect_from_env!() :: config()
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

      iex> Clawbreaker.connected?()
      true

  """
  @spec connected?() :: boolean()
  def connected? do
    Config.configured?()
  end

  @doc """
  Get current connection info.

  ## Examples

      Clawbreaker.whoami()
      #=> %{"user" => "jim@example.com", "org" => "acme-corp"}

  """
  @spec whoami() :: map()
  def whoami do
    Clawbreaker.Client.get!("/v1/whoami")
  end

  @doc """
  List organizations you belong to.

  ## Examples

      Clawbreaker.orgs()
      #=> [%{"id" => "acme-corp", "name" => "Acme Corporation", "role" => "admin"}]

  """
  @spec orgs() :: [map()]
  def orgs do
    case Clawbreaker.Client.get("/v1/orgs") do
      {:ok, %{"data" => orgs}} -> orgs
      {:ok, orgs} when is_list(orgs) -> orgs
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  @doc """
  Disconnect and clear stored credentials.

  ## Examples

      Clawbreaker.disconnect()
      :ok

  """
  @spec disconnect() :: :ok
  def disconnect do
    Config.clear()
  end
end
