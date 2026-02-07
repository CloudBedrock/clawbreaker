defmodule Clawbreaker.Agent do
  @moduledoc """
  Functions for managing Clawbreaker agents.

  ## Creating Agents

      agent = Clawbreaker.Agent.create!(
        name: "Support Bot",
        model: "claude-sonnet-4",
        system_prompt: "You are a helpful support agent.",
        tools: [:search_kb, :create_ticket]
      )

  ## Testing Agents

      # Simple test
      response = Clawbreaker.Agent.test!(agent, "Hello!")

      # Streaming
      Clawbreaker.Agent.stream_test(agent, "Tell me a story", fn event ->
        case event do
          {:chunk, text} -> IO.write(text)
          {:tool_call, tool} -> IO.puts("Calling \#{tool.name}...")
          :done -> IO.puts("Done!")
        end
      end)

  ## Deploying Agents

      {:ok, deployment} = Clawbreaker.Agent.deploy(agent, env: :production)

  """

  alias Clawbreaker.Client

  defstruct [:id, :name, :model, :system_prompt, :tools, :temperature, :metadata]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          model: String.t(),
          system_prompt: String.t(),
          tools: [atom() | String.t()],
          temperature: float(),
          metadata: map()
        }

  @doc """
  Create a new agent.

  ## Options

    * `:name` - Agent name (required)
    * `:model` - Model ID like "claude-sonnet-4" (required)
    * `:system_prompt` - System prompt (required)
    * `:tools` - List of tool IDs (optional)
    * `:temperature` - Temperature 0.0-1.0 (default: 0.7)

  ## Examples

      Clawbreaker.Agent.create!(
        name: "My Bot",
        model: "claude-sonnet-4",
        system_prompt: "You are helpful."
      )

  """
  def create!(opts) do
    case create(opts) do
      {:ok, agent} -> agent
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  def create(opts) do
    body = %{
      name: Keyword.fetch!(opts, :name),
      model: Keyword.fetch!(opts, :model),
      system_prompt: Keyword.fetch!(opts, :system_prompt),
      tools: Keyword.get(opts, :tools, []),
      temperature: Keyword.get(opts, :temperature, 0.7)
    }

    case Client.post("/v1/agents", body) do
      {:ok, data} -> {:ok, from_api(data)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Build an agent struct locally without creating it on the server.

  Useful for testing configurations before committing.
  """
  def new(opts) do
    %__MODULE__{
      name: Keyword.fetch!(opts, :name),
      model: Keyword.fetch!(opts, :model),
      system_prompt: Keyword.fetch!(opts, :system_prompt),
      tools: Keyword.get(opts, :tools, []),
      temperature: Keyword.get(opts, :temperature, 0.7),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  List all agents.
  """
  def list(opts \\ []) do
    params = Keyword.take(opts, [:limit, :offset])

    case Client.get("/v1/agents", params: params) do
      {:ok, %{"data" => agents}} -> {:ok, Enum.map(agents, &from_api/1)}
      {:error, _} = error -> error
    end
  end

  def list!(opts \\ []) do
    case list(opts) do
      {:ok, agents} -> agents
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  @doc """
  Get an agent by ID.
  """
  def get(id) do
    case Client.get("/v1/agents/#{id}") do
      {:ok, data} -> {:ok, from_api(data)}
      {:error, _} = error -> error
    end
  end

  def get!(id) do
    case get(id) do
      {:ok, agent} -> agent
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  @doc """
  Update an agent.
  """
  def update(%__MODULE__{id: id} = _agent, updates) when is_binary(id) do
    body = Map.new(updates)

    case Client.put("/v1/agents/#{id}", body) do
      {:ok, data} -> {:ok, from_api(data)}
      {:error, _} = error -> error
    end
  end

  def update!(%__MODULE__{} = agent, updates) do
    case update(agent, updates) do
      {:ok, agent} -> agent
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  @doc """
  Delete an agent.
  """
  def delete(%__MODULE__{id: id}) when is_binary(id) do
    Client.delete("/v1/agents/#{id}")
  end

  def delete!(agent) do
    case delete(agent) do
      {:ok, _} -> :ok
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  @doc """
  Test an agent with a message or conversation.

  ## Examples

      # Single message
      Clawbreaker.Agent.test!(agent, "Hello!")

      # Conversation history
      messages = [
        %{role: "user", content: "Hi"},
        %{role: "assistant", content: "Hello!"},
        %{role: "user", content: "How are you?"}
      ]
      Clawbreaker.Agent.test!(agent, messages)

  """
  def test!(agent, message_or_messages) do
    case test(agent, message_or_messages) do
      {:ok, response} -> response
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  def test(agent, message) when is_binary(message) do
    test(agent, [%{role: "user", content: message}])
  end

  def test(%__MODULE__{id: id} = _agent, messages) when is_list(messages) and is_binary(id) do
    Client.post("/v1/agents/#{id}/test", %{messages: messages})
  end

  def test(%__MODULE__{} = agent, messages) when is_list(messages) do
    # Local agent (not yet created) - create temporarily for test
    body = %{
      agent: to_api(agent),
      messages: messages
    }

    Client.post("/v1/agents/test", body)
  end

  @doc """
  Test an agent with streaming response.

  The callback receives events:
    * `{:chunk, text}` - Text chunk
    * `{:tool_call, tool}` - Tool being called
    * `{:tool_result, result}` - Tool result
    * `:done` - Stream complete

  ## Examples

      Clawbreaker.Agent.stream_test(agent, "Tell me a story", fn
        {:chunk, text} -> IO.write(text)
        {:tool_call, tool} -> IO.puts("\\n🔧 \#{tool["name"]}")
        :done -> IO.puts("\\n✅ Done")
        _ -> :ok
      end)

  """
  def stream_test(%__MODULE__{id: id} = _agent, message, callback) when is_binary(id) do
    messages = if is_binary(message), do: [%{role: "user", content: message}], else: message

    Client.stream("/v1/agents/#{id}/test/stream", %{messages: messages}, fn event ->
      parsed = parse_stream_event(event)
      callback.(parsed)
    end)
  end

  def stream_test(%__MODULE__{} = agent, message, callback) do
    messages = if is_binary(message), do: [%{role: "user", content: message}], else: message

    Client.stream("/v1/agents/test/stream", %{agent: to_api(agent), messages: messages}, fn event ->
      parsed = parse_stream_event(event)
      callback.(parsed)
    end)
  end

  @doc """
  Deploy an agent to staging or production.

  ## Options

    * `:env` - `:staging` or `:production` (default: `:staging`)
    * `:note` - Deployment note

  ## Examples

      {:ok, deployment} = Clawbreaker.Agent.deploy(agent, env: :production)

  """
  def deploy(%__MODULE__{id: id} = _agent, opts \\ []) when is_binary(id) do
    body = %{
      environment: Keyword.get(opts, :env, :staging),
      note: Keyword.get(opts, :note)
    }

    Client.post("/v1/agents/#{id}/deploy", body)
  end

  def deploy!(%__MODULE__{} = agent, opts \\ []) do
    case deploy(agent, opts) do
      {:ok, deployment} -> deployment
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  # Private helpers

  defp from_api(data) do
    %__MODULE__{
      id: data["id"],
      name: data["name"],
      model: data["model"],
      system_prompt: data["system_prompt"],
      tools: data["tools"] || [],
      temperature: data["temperature"] || 0.7,
      metadata: data["metadata"] || %{}
    }
  end

  defp to_api(%__MODULE__{} = agent) do
    %{
      name: agent.name,
      model: agent.model,
      system_prompt: agent.system_prompt,
      tools: agent.tools,
      temperature: agent.temperature
    }
  end

  defp parse_stream_event(%{"type" => "chunk", "text" => text}), do: {:chunk, text}
  defp parse_stream_event(%{"type" => "tool_call"} = e), do: {:tool_call, e}
  defp parse_stream_event(%{"type" => "tool_result"} = e), do: {:tool_result, e}
  defp parse_stream_event(%{"type" => "done"}), do: :done
  defp parse_stream_event(other), do: {:unknown, other}
end
