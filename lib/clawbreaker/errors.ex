defmodule Clawbreaker.ConnectionError do
  @moduledoc "Raised when connection to Clawbreaker fails."
  defexception [:message]

  @impl true
  def exception(reason) when is_binary(reason) do
    %__MODULE__{message: reason}
  end

  def exception(reason) do
    %__MODULE__{message: inspect(reason)}
  end
end

defmodule Clawbreaker.APIError do
  @moduledoc "Raised when an API request fails."
  defexception [:message, :status, :body]

  @impl true
  def exception(:unauthorized) do
    %__MODULE__{
      message: "Unauthorized. Check your API key or re-authenticate with Clawbreaker.connect!()",
      status: 401
    }
  end

  def exception(:not_found) do
    %__MODULE__{
      message: "Resource not found",
      status: 404
    }
  end

  def exception(%{status: status, body: body}) do
    message =
      case body do
        %{"error" => %{"message" => msg}} -> msg
        %{"error" => msg} when is_binary(msg) -> msg
        _ -> "API request failed with status #{status}"
      end

    %__MODULE__{message: message, status: status, body: body}
  end

  def exception(reason) do
    %__MODULE__{message: inspect(reason)}
  end
end

defmodule Clawbreaker.NotFoundError do
  @moduledoc "Raised when a resource is not found."
  defexception [:message, :resource, :id]

  @impl true
  def exception(opts) do
    resource = opts[:resource] || "Resource"
    id = opts[:id]

    message =
      if id do
        "#{resource} not found: #{id}"
      else
        "#{resource} not found"
      end

    %__MODULE__{message: message, resource: resource, id: id}
  end
end
