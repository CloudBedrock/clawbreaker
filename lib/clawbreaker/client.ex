defmodule Clawbreaker.Client do
  @moduledoc false

  alias Clawbreaker.Config

  @type response :: {:ok, map() | list()} | {:error, term()}

  @doc false
  @spec get!(String.t(), keyword()) :: map() | list()
  def get!(path, opts \\ []) do
    case get(path, opts) do
      {:ok, body} -> body
      {:error, error} -> raise Clawbreaker.APIError, error
    end
  end

  @doc false
  @spec get(String.t(), keyword()) :: response()
  def get(path, opts \\ []) do
    request(:get, path, nil, opts)
  end

  @doc false
  @spec post!(String.t(), map(), keyword()) :: map() | list()
  def post!(path, body, opts \\ []) do
    case post(path, body, opts) do
      {:ok, body} -> body
      {:error, error} -> raise Clawbreaker.APIError, error
    end
  end

  @doc false
  @spec post(String.t(), map(), keyword()) :: response()
  def post(path, body, opts \\ []) do
    request(:post, path, body, opts)
  end

  @doc false
  @spec put!(String.t(), map(), keyword()) :: map() | list()
  def put!(path, body, opts \\ []) do
    case put(path, body, opts) do
      {:ok, body} -> body
      {:error, error} -> raise Clawbreaker.APIError, error
    end
  end

  @doc false
  @spec put(String.t(), map(), keyword()) :: response()
  def put(path, body, opts \\ []) do
    request(:put, path, body, opts)
  end

  @doc false
  @spec delete!(String.t(), keyword()) :: map() | list()
  def delete!(path, opts \\ []) do
    case delete(path, opts) do
      {:ok, body} -> body
      {:error, error} -> raise Clawbreaker.APIError, error
    end
  end

  @doc false
  @spec delete(String.t(), keyword()) :: response()
  def delete(path, opts \\ []) do
    request(:delete, path, nil, opts)
  end

  @doc false
  @spec stream(String.t(), map(), (map() -> any()), keyword()) :: {:ok, term()} | {:error, term()}
  def stream(path, body, callback, opts \\ []) do
    url = build_url(path)
    headers = build_headers(opts)

    Req.post(url,
      json: body,
      headers: headers,
      receive_timeout: 120_000,
      into: fn {:data, data}, acc ->
        data
        |> String.split("\n", trim: true)
        |> Enum.each(fn line ->
          case Jason.decode(line) do
            {:ok, event} -> callback.(event)
            {:error, _} -> :ok
          end
        end)

        {:cont, acc}
      end
    )
  end

  defp request(method, path, body, opts) do
    url = build_url(path)
    headers = build_headers(opts)

    request_opts =
      [method: method, url: url, headers: headers]
      |> maybe_add_body(body)
      |> maybe_add_params(opts[:params])

    case Req.request(request_opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_url(path) do
    base = Config.get(:url) || Config.default_url()
    "#{base}#{path}"
  end

  defp build_headers(opts) do
    api_key = opts[:api_key] || Config.get(:api_key)

    headers = [
      {"content-type", "application/json"},
      {"accept", "application/json"},
      {"user-agent", "clawbreaker-elixir/#{Mix.Project.config()[:version]}"}
    ]

    if api_key do
      [{"authorization", "Bearer #{api_key}"} | headers]
    else
      headers
    end
  end

  defp maybe_add_body(opts, nil), do: opts
  defp maybe_add_body(opts, body), do: Keyword.put(opts, :json, body)

  defp maybe_add_params(opts, nil), do: opts
  defp maybe_add_params(opts, params), do: Keyword.put(opts, :params, params)
end
