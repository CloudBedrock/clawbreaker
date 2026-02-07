defmodule Clawbreaker.Auth do
  @moduledoc false

  @callback_port 19283

  @doc """
  Perform interactive OAuth flow. Opens browser and waits for callback.
  """
  def interactive_oauth(base_url, opts \\ []) do
    # Generate state for CSRF protection
    state = :crypto.strong_rand_bytes(16) |> Base.url_encode64()

    # Build authorize URL
    callback_url = "http://localhost:#{@callback_port}/callback"
    org = opts[:org]

    params =
      %{
        response_type: "code",
        redirect_uri: callback_url,
        state: state
      }
      |> maybe_add_org(org)

    authorize_url = "#{base_url}/oauth/authorize?#{URI.encode_query(params)}"

    # Start callback server
    {:ok, server} = start_callback_server(state)

    # Open browser
    open_browser(authorize_url)

    IO.puts("Opening browser for authentication...")
    IO.puts("If the browser doesn't open, visit: #{authorize_url}")

    # Wait for callback (with timeout)
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

    {:ok, spawn_link(fn -> run_callback_server(parent, expected_state) end)}
  end

  defp stop_callback_server(pid) do
    Process.exit(pid, :normal)
  end

  defp run_callback_server(parent, expected_state) do
    # Simple HTTP server to receive OAuth callback
    {:ok, socket} = :gen_tcp.listen(@callback_port, [:binary, active: false, reuseaddr: true])

    case :gen_tcp.accept(socket, 60_000) do
      {:ok, client} ->
        {:ok, data} = :gen_tcp.recv(client, 0, 5_000)
        response = handle_callback_request(data, expected_state, parent)

        :gen_tcp.send(client, response)
        :gen_tcp.close(client)
        :gen_tcp.close(socket)

      {:error, :timeout} ->
        :gen_tcp.close(socket)
        send(parent, {:oauth_error, expected_state, :timeout})
    end
  end

  defp handle_callback_request(data, expected_state, parent) do
    # Parse the GET request
    case parse_callback_params(data) do
      {:ok, %{"code" => code, "state" => ^expected_state}} ->
        send(parent, {:oauth_callback, expected_state, code})
        success_response()

      {:ok, %{"error" => error}} ->
        send(parent, {:oauth_error, expected_state, error})
        error_response(error)

      {:ok, %{"state" => wrong_state}} ->
        send(parent, {:oauth_error, expected_state, :state_mismatch})
        error_response("State mismatch: expected #{expected_state}, got #{wrong_state}")

      _ ->
        send(parent, {:oauth_error, expected_state, :invalid_callback})
        error_response("Invalid callback")
    end
  end

  defp parse_callback_params(data) do
    case Regex.run(~r/GET \/callback\?([^ ]+)/, data) do
      [_, query_string] ->
        {:ok, URI.decode_query(query_string)}

      _ ->
        {:error, :invalid_request}
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
    </body>
    </html>
    """

    "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: #{byte_size(body)}\r\n\r\n#{body}"
  end

  defp error_response(error) do
    body = """
    <!DOCTYPE html>
    <html>
    <head><title>Clawbreaker</title></head>
    <body style="font-family: system-ui; text-align: center; padding: 50px;">
      <h1>❌ Authentication Failed</h1>
      <p>#{error}</p>
      <p>Please try again.</p>
    </body>
    </html>
    """

    "HTTP/1.1 400 Bad Request\r\nContent-Type: text/html\r\nContent-Length: #{byte_size(body)}\r\n\r\n#{body}"
  end

  defp open_browser(url) do
    case :os.type() do
      {:unix, :darwin} -> System.cmd("open", [url])
      {:unix, _} -> System.cmd("xdg-open", [url])
      {:win32, _} -> System.cmd("cmd", ["/c", "start", url])
    end
  end

  defp maybe_add_org(params, nil), do: params
  defp maybe_add_org(params, org), do: Map.put(params, :org, org)
end
