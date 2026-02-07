defmodule Clawbreaker.ConnectionError do
  @moduledoc """
  Raised when connection to Clawbreaker fails.

  This can happen when:
  - The API key is invalid
  - The server is unreachable
  - OAuth flow times out or is cancelled
  """
  defexception [:message]

  @impl true
  def exception(reason) when is_binary(reason) do
    %__MODULE__{message: reason}
  end

  def exception(:timeout) do
    %__MODULE__{message: "Connection timed out"}
  end

  def exception(reason) do
    %__MODULE__{message: inspect(reason)}
  end
end

defmodule Clawbreaker.APIError do
  @moduledoc """
  Raised when an API request fails.

  Contains information about the HTTP status and response body when available.
  """
  defexception [:message, :status, :body]

  @impl true
  def exception(:unauthorized) do
    %__MODULE__{
      message: "Unauthorized. Check your API key or re-authenticate with Clawbreaker.connect!()",
      status: 401,
      body: nil
    }
  end

  def exception(:not_found) do
    %__MODULE__{
      message: "Resource not found",
      status: 404,
      body: nil
    }
  end

  def exception(%{status: status, body: body}) do
    message = extract_error_message(body, status)

    %__MODULE__{
      message: message,
      status: status,
      body: body
    }
  end

  def exception(reason) when is_binary(reason) do
    %__MODULE__{message: reason, status: nil, body: nil}
  end

  def exception(reason) do
    %__MODULE__{message: inspect(reason), status: nil, body: nil}
  end

  defp extract_error_message(body, status) do
    case body do
      %{"error" => %{"message" => msg}} when is_binary(msg) -> msg
      %{"error" => msg} when is_binary(msg) -> msg
      %{"message" => msg} when is_binary(msg) -> msg
      _ -> "API request failed with status #{status}"
    end
  end
end
