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
          {:tool_call, tool} -> IO.puts("Calling \#{tool["name"]}...")
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

  @type create_opts :: [
          name: String.t(),
          model: String.t(),
          system_prompt: String.t(),
          tools: [atom() | String.t()],
          temperature: float()
        ]

  @type deploy_opts :: [env: :staging | :production, note: String.t()]

  @type stream_event ::
          {:chunk, String.t()}
          | {:tool_call, map()}
          | {:tool_result, map()}
          | :done
          | {:unknown, term()}

  @type message :: %{role: String.t(), content: String.t()} | %{atom() => term()}
  @type messages :: [message()]

  @doc """
  Create a new agent on the server.

  ## Options

    * `:name` - Agent name (required)
    * `:model` - Model ID like `"claude-sonnet-4"` (required)
    * `:system_prompt` - System prompt (required)
    * `:tools` - List of tool IDs (optional, default: `[]`)
    * `:temperature` - Temperature 0.0-1.0 (optional, default: `0.7`)

  ## Examples

      Clawbreaker.Agent.create!(
        name: "My Bot",
        model: "claude-sonnet-4",
        system_prompt: "You are helpful."
      )

  """
  @spec create!(create_opts()) :: t()
  def create!(opts) do
    case create(opts) do
      {:ok, agent} -> agent
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  @spec create(create_opts()) :: {:ok, t()} | {:error, term()}
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

  ## Examples

      agent = Clawbreaker.Agent.new(
        name: "Test Bot",
        model: "claude-sonnet-4",
        system_prompt: "You are helpful."
      )

  """
  @spec new(create_opts()) :: t()
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

  ## Options

    * `:limit` - Maximum number of agents to return
    * `:offset` - Number of agents to skip

  ## Examples

      Clawbreaker.Agent.list!(limit: 10)

  """
  @spec list!(keyword()) :: [t()]
  def list!(opts \\ []) do
    case list(opts) do
      {:ok, agents} -> agents
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  @spec list(keyword()) :: {:ok, [t()]} | {:error, term()}
  def list(opts \\ []) do
    params = Keyword.take(opts, [:limit, :offset])

    case Client.get("/v1/agents", params: params) do
      {:ok, %{"data" => agents}} -> {:ok, Enum.map(agents, &from_api/1)}
      {:ok, agents} when is_list(agents) -> {:ok, Enum.map(agents, &from_api/1)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Get an agent by ID.

  ## Examples

      agent = Clawbreaker.Agent.get!("ag_123")

  """
  @spec get!(String.t()) :: t()
  def get!(id) do
    case get(id) do
      {:ok, agent} -> agent
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  @spec get(String.t()) :: {:ok, t()} | {:error, term()}
  def get(id) do
    case Client.get("/v1/agents/#{id}") do
      {:ok, data} -> {:ok, from_api(data)}
      {:error, _} = error -> error
    end
  end

  @doc """
  Update an agent.

  ## Examples

      Clawbreaker.Agent.update!(agent, temperature: 0.5, name: "New Name")

  """
  @spec update!(t(), keyword()) :: t()
  def update!(%__MODULE__{} = agent, updates) do
    case update(agent, updates) do
      {:ok, agent} -> agent
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  @spec update(t(), keyword()) :: {:ok, t()} | {:error, term()}
  def update(%__MODULE__{id: id}, updates) when is_binary(id) do
    body = Map.new(updates)

    case Client.put("/v1/agents/#{id}", body) do
      {:ok, data} -> {:ok, from_api(data)}
      {:error, _} = error -> error
    end
  end

  def update(%__MODULE__{id: nil}, _updates) do
    {:error, "Cannot update an agent that hasn't been created. Use create/1 first."}
  end

  @doc """
  Delete an agent.

  ## Examples

      Clawbreaker.Agent.delete!(agent)

  """
  @spec delete!(t()) :: :ok
  def delete!(%__MODULE__{} = agent) do
    case delete(agent) do
      {:ok, _} -> :ok
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  @spec delete(t()) :: {:ok, map()} | {:error, term()}
  def delete(%__MODULE__{id: id}) when is_binary(id) do
    Client.delete("/v1/agents/#{id}")
  end

  def delete(%__MODULE__{id: nil}) do
    {:error, "Cannot delete an agent that hasn't been created."}
  end

  @doc """
  Test an agent with a message or conversation.

  ## Examples

      # Single message
      response = Clawbreaker.Agent.test!(agent, "Hello!")

      # Conversation history
      messages = [
        %{role: "user", content: "Hi"},
        %{role: "assistant", content: "Hello!"},
        %{role: "user", content: "How are you?"}
      ]
      response = Clawbreaker.Agent.test!(agent, messages)

  """
  @spec test!(t(), String.t() | messages()) :: map()
  def test!(agent, message_or_messages) do
    case test(agent, message_or_messages) do
      {:ok, response} -> response
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  @spec test(t(), String.t() | messages()) :: {:ok, map()} | {:error, term()}
  def test(agent, message) when is_binary(message) do
    test(agent, [%{role: "user", content: message}])
  end

  def test(%__MODULE__{id: id}, messages) when is_list(messages) and is_binary(id) do
    Client.post("/v1/agents/#{id}/test", %{messages: messages})
  end

  def test(%__MODULE__{id: nil} = agent, messages) when is_list(messages) do
    body = %{
      agent: to_api(agent),
      messages: messages
    }

    Client.post("/v1/agents/test", body)
  end

  @doc """
  Test an agent with streaming response.

  The callback receives events:
    * `{:chunk, text}` - Text chunk from the model
    * `{:tool_call, tool}` - Tool being called
    * `{:tool_result, result}` - Tool execution result
    * `:done` - Stream complete

  ## Examples

      Clawbreaker.Agent.stream_test(agent, "Tell me a story", fn
        {:chunk, text} -> IO.write(text)
        {:tool_call, tool} -> IO.puts("\\n🔧 Calling \#{tool["name"]}...")
        :done -> IO.puts("\\n✅ Done")
        _ -> :ok
      end)

  """
  @spec stream_test(t(), String.t() | messages(), (stream_event() -> any())) :: :ok
  def stream_test(%__MODULE__{id: id}, message, callback) when is_binary(id) do
    messages = normalize_messages(message)

    Client.stream("/v1/agents/#{id}/test/stream", %{messages: messages}, fn event ->
      callback.(parse_stream_event(event))
    end)

    :ok
  end

  def stream_test(%__MODULE__{id: nil} = agent, message, callback) do
    messages = normalize_messages(message)

    Client.stream(
      "/v1/agents/test/stream",
      %{agent: to_api(agent), messages: messages},
      fn event ->
        callback.(parse_stream_event(event))
      end
    )

    :ok
  end

  @doc """
  Deploy an agent to staging or production.

  ## Options

    * `:env` - `:staging` or `:production` (default: `:staging`)
    * `:note` - Deployment note (optional)

  ## Examples

      {:ok, deployment} = Clawbreaker.Agent.deploy(agent, env: :production)
      IO.puts("Deployed to: \#{deployment["endpoint"]}")

  """
  @spec deploy(t(), deploy_opts()) :: {:ok, map()} | {:error, term()}
  def deploy(%__MODULE__{id: id}, opts \\ []) when is_binary(id) do
    body = %{
      environment: Keyword.get(opts, :env, :staging),
      note: Keyword.get(opts, :note)
    }

    Client.post("/v1/agents/#{id}/deploy", body)
  end

  @spec deploy!(t(), deploy_opts()) :: map()
  def deploy!(%__MODULE__{} = agent, opts \\ []) do
    case deploy(agent, opts) do
      {:ok, deployment} -> deployment
      {:error, reason} -> raise Clawbreaker.APIError, reason
    end
  end

  # Private helpers

  defp from_api(data) when is_map(data) do
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

  defp normalize_messages(message) when is_binary(message) do
    [%{role: "user", content: message}]
  end

  defp normalize_messages(messages) when is_list(messages), do: messages

  defp parse_stream_event(%{"type" => "chunk", "text" => text}), do: {:chunk, text}
  defp parse_stream_event(%{"type" => "tool_call"} = e), do: {:tool_call, e}
  defp parse_stream_event(%{"type" => "tool_result"} = e), do: {:tool_result, e}
  defp parse_stream_event(%{"type" => "done"}), do: :done
  defp parse_stream_event(other), do: {:unknown, other}
end
