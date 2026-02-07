defmodule Clawbreaker.Config do
  @moduledoc false
  use Agent

  @default_url "https://api.clawbreaker.ai"
  @credentials_path Path.expand("~/.clawbreaker/credentials.json")

  @doc false
  def start_link(_opts) do
    Agent.start_link(fn -> load_initial_config() end, name: __MODULE__)
  end

  @doc false
  @spec default_url() :: String.t()
  def default_url, do: @default_url

  @doc false
  @spec configure(keyword()) :: {:ok, map()}
  def configure(opts) do
    config = %{
      url: opts[:url] || @default_url,
      api_key: opts[:api_key],
      org: opts[:org]
    }

    Agent.update(__MODULE__, fn _ -> config end)

    if opts[:persist] != false do
      store_credentials(config)
    end

    {:ok, config}
  end

  @doc false
  @spec configured?() :: boolean()
  def configured? do
    case get() do
      %{api_key: key} when is_binary(key) and key != "" -> true
      _ -> false
    end
  end

  @doc false
  @spec get() :: map()
  def get do
    Agent.get(__MODULE__, & &1)
  end

  @doc false
  @spec get(atom()) :: term()
  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  @doc false
  @spec clear() :: :ok
  def clear do
    Agent.update(__MODULE__, fn _ -> %{} end)
    File.rm(@credentials_path)
    :ok
  end

  @doc false
  @spec has_stored_credentials?() :: boolean()
  def has_stored_credentials? do
    File.exists?(@credentials_path)
  end

  @doc false
  @spec load_stored_credentials() :: {:ok, map()} | {:error, term()}
  def load_stored_credentials do
    with {:ok, content} <- File.read(@credentials_path),
         {:ok, creds} <- Jason.decode(content, keys: :atoms) do
      configure(Map.to_list(creds))
    end
  end

  defp load_initial_config do
    %{
      url: Application.get_env(:clawbreaker, :url, @default_url),
      api_key: Application.get_env(:clawbreaker, :api_key),
      org: Application.get_env(:clawbreaker, :org)
    }
  end

  defp store_credentials(config) do
    dir = Path.dirname(@credentials_path)
    File.mkdir_p!(dir)

    # Set directory permissions to owner-only
    File.chmod(dir, 0o700)

    content = Jason.encode!(config, pretty: true)
    File.write!(@credentials_path, content)

    # Set file permissions to owner-only
    File.chmod(@credentials_path, 0o600)
  end
end
