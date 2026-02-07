defmodule Clawbreaker.Auth do
  @moduledoc false

  @callback_port 19_283

  @doc """
  Perform interactive OAuth flow. Opens browser and waits for callback.
  """
  @spec interactive_oauth(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def interactive_oauth(base_url, opts \\ []) do
    state = generate_state()
    callback_url = "http://localhost:#{@callback_port}/callback"

    authorize_url = build_authorize_url(base_url, callback_url, state, opts)

    with {:ok, server} <- start_callback_server(state),
         :ok <- open_browser(authorize_url) do
      IO.puts("Opening browser for authentication...")
      IO.puts("If the browser doesn't open, visit: #{authorize_url}")

      receive do
        {:oauth_callback, ^state, code} ->
          stop_callback_server(server)
          exchange_code(base_url, code, callback_url)

        {:oauth_error, ^state, error} ->
          stop_callback_server(server)
          {:error, error}
      after
        300_000 ->
          stop_callback_server(server)
          {:error, :timeout}
      end
    end
  end

  defp generate_state do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp build_authorize_url(base_url, callback_url, state, opts) do
    params =
      %{
        response_type: "code",
        redirect_uri: callback_url,
        state: state
      }
      |> maybe_add_org(opts[:org])

    "#{base_url}/oauth/authorize?#{URI.encode_query(params)}"
  end

  defp exchange_code(base_url, code, redirect_uri) do
    body = %{
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri
    }

    case Req.post("#{base_url}/oauth/token", json: body) do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        Clawbreaker.Config.configure(url: base_url, api_key: token)

      {:ok, %{body: body}} ->
        {:error, body["error"] || "Token exchange failed"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_callback_server(expected_state) do
    parent = self()
    pid = spawn_link(fn -> run_callback_server(parent, expected_state) end)
    {:ok, pid}
  end

  defp stop_callback_server(pid) do
    Process.unlink(pid)
    Process.exit(pid, :shutdown)
  end

  defp run_callback_server(parent, expected_state) do
    {:ok, socket} =
      :gen_tcp.listen(@callback_port, [
        :binary,
        active: false,
        reuseaddr: true,
        packet: :http_bin
      ])

    case :gen_tcp.accept(socket, 60_000) do
      {:ok, client} ->
        handle_client(client, expected_state, parent)
        :gen_tcp.close(socket)

      {:error, :timeout} ->
        :gen_tcp.close(socket)
        send(parent, {:oauth_error, expected_state, :timeout})
    end
  end

  defp handle_client(client, expected_state, parent) do
    case read_request(client) do
      {:ok, path} ->
        params = parse_query_params(path)
        response = handle_callback(params, expected_state, parent)
        :gen_tcp.send(client, response)
        :gen_tcp.close(client)

      {:error, _reason} ->
        :gen_tcp.close(client)
    end
  end

  defp read_request(client) do
    case :gen_tcp.recv(client, 0, 5_000) do
      {:ok, {:http_request, :GET, {:abs_path, path}, _}} ->
        # Drain remaining headers
        drain_headers(client)
        {:ok, path}

      {:ok, _other} ->
        {:error, :invalid_request}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp drain_headers(client) do
    case :gen_tcp.recv(client, 0, 1_000) do
      {:ok, :http_eoh} -> :ok
      {:ok, {:http_header, _, _, _, _}} -> drain_headers(client)
      _ -> :ok
    end
  end

  defp parse_query_params(path) do
    case String.split(to_string(path), "?", parts: 2) do
      [_, query] -> URI.decode_query(query)
      _ -> %{}
    end
  end

  defp handle_callback(params, expected_state, parent) do
    case params do
      %{"code" => code, "state" => ^expected_state} ->
        send(parent, {:oauth_callback, expected_state, code})
        success_response()

      %{"error" => error} ->
        send(parent, {:oauth_error, expected_state, error})
        error_response(error)

      %{"state" => wrong_state} ->
        send(parent, {:oauth_error, expected_state, :state_mismatch})
        error_response("State mismatch: expected #{expected_state}, got #{wrong_state}")

      _ ->
        send(parent, {:oauth_error, expected_state, :invalid_callback})
        error_response("Invalid callback")
    end
  end

  defp success_response do
    body = """
    <!DOCTYPE html>
    <html>
    <head><title>Clawbreaker</title></head>
    <body style="font-family: system-ui; text-align: center; padding: 50px;">
      <h1>✅ Connected!</h1>
      <p>You can close this window and return to Livebook.</p>
      <script>window.close()</script>
    </body>
    </html>
    """

    http_response(200, "OK", body)
  end

  defp error_response(error) do
    body = """
    <!DOCTYPE html>
    <html>
    <head><title>Clawbreaker</title></head>
    <body style="font-family: system-ui; text-align: center; padding: 50px;">
      <h1>❌ Authentication Failed</h1>
      <p>#{error}</p>
      <p>Please close this window and try again.</p>
    </body>
    </html>
    """

    http_response(400, "Bad Request", body)
  end

  defp http_response(status, status_text, body) do
    """
    HTTP/1.1 #{status} #{status_text}\r
    Content-Type: text/html; charset=utf-8\r
    Content-Length: #{byte_size(body)}\r
    Connection: close\r
    \r
    #{body}
    """
  end

  defp open_browser(url) do
    case :os.type() do
      {:unix, :darwin} ->
        System.cmd("open", [url], stderr_to_stdout: true)
        :ok

      {:unix, _} ->
        System.cmd("xdg-open", [url], stderr_to_stdout: true)
        :ok

      {:win32, _} ->
        System.cmd("cmd", ["/c", "start", String.replace(url, "&", "^&")], stderr_to_stdout: true)
        :ok
    end
  end

  defp maybe_add_org(params, nil), do: params
  defp maybe_add_org(params, org), do: Map.put(params, :org, org)
end
