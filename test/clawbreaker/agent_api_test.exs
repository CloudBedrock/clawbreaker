defmodule Clawbreaker.AgentAPITest do
  use ExUnit.Case, async: false

  import Mox

  alias Clawbreaker.Agent

  setup :verify_on_exit!

  setup do
    # Use mock client for API tests
    Application.put_env(:clawbreaker, :client, Clawbreaker.ClientMock)

    # Connect with test credentials
    Clawbreaker.connect!(api_key: "test_key", persist: false)

    on_exit(fn ->
      Application.put_env(:clawbreaker, :client, Clawbreaker.Client)
    end)

    :ok
  end

  describe "create/1" do
    test "creates agent via API and returns struct" do
      expect(Clawbreaker.ClientMock, :post, fn "/v1/agents", body, _opts ->
        assert body.name == "Test Bot"
        assert body.model == "claude-sonnet-4"
        assert body.system_prompt == "You are helpful."
        assert body.temperature == 0.7

        {:ok, %{
          "id" => "ag_123",
          "name" => "Test Bot",
          "model" => "claude-sonnet-4",
          "system_prompt" => "You are helpful.",
          "tools" => [],
          "temperature" => 0.7
        }}
      end)

      {:ok, agent} = Agent.create(
        name: "Test Bot",
        model: "claude-sonnet-4",
        system_prompt: "You are helpful."
      )

      assert %Agent{} = agent
      assert agent.id == "ag_123"
      assert agent.name == "Test Bot"
    end

    test "returns error on API failure" do
      expect(Clawbreaker.ClientMock, :post, fn "/v1/agents", _body, _opts ->
        {:error, %{status: 400, body: %{"error" => "Invalid model"}}}
      end)

      result = Agent.create(
        name: "Test",
        model: "invalid-model",
        system_prompt: "Test"
      )

      assert {:error, %{status: 400}} = result
    end
  end

  describe "list/1" do
    test "returns list of agents" do
      expect(Clawbreaker.ClientMock, :get, fn "/v1/agents", _opts ->
        {:ok, %{
          "data" => [
            %{"id" => "ag_1", "name" => "Bot 1", "model" => "claude-sonnet-4", "system_prompt" => "Test", "tools" => [], "temperature" => 0.7},
            %{"id" => "ag_2", "name" => "Bot 2", "model" => "gpt-4o", "system_prompt" => "Test", "tools" => [], "temperature" => 0.5}
          ]
        }}
      end)

      {:ok, agents} = Agent.list()

      assert length(agents) == 2
      assert Enum.all?(agents, &match?(%Agent{}, &1))
      assert Enum.map(agents, & &1.id) == ["ag_1", "ag_2"]
    end

    test "handles empty list" do
      expect(Clawbreaker.ClientMock, :get, fn "/v1/agents", _opts ->
        {:ok, %{"data" => []}}
      end)

      {:ok, agents} = Agent.list()
      assert agents == []
    end
  end

  describe "get/1" do
    test "returns agent by ID" do
      expect(Clawbreaker.ClientMock, :get, fn "/v1/agents/ag_123", _opts ->
        {:ok, %{
          "id" => "ag_123",
          "name" => "My Bot",
          "model" => "claude-sonnet-4",
          "system_prompt" => "You are helpful.",
          "tools" => ["search", "calculator"],
          "temperature" => 0.8
        }}
      end)

      {:ok, agent} = Agent.get("ag_123")

      assert agent.id == "ag_123"
      assert agent.name == "My Bot"
      assert agent.tools == ["search", "calculator"]
      assert agent.temperature == 0.8
    end

    test "returns error for non-existent agent" do
      expect(Clawbreaker.ClientMock, :get, fn "/v1/agents/ag_nonexistent", _opts ->
        {:error, :not_found}
      end)

      result = Agent.get("ag_nonexistent")
      assert {:error, :not_found} = result
    end
  end

  describe "update/2" do
    test "updates agent and returns updated struct" do
      agent = %Agent{id: "ag_123", name: "Old Name", model: "claude-sonnet-4", system_prompt: "Test", tools: [], temperature: 0.7}

      expect(Clawbreaker.ClientMock, :put, fn "/v1/agents/ag_123", body, _opts ->
        assert body.name == "New Name"
        assert body.temperature == 0.5

        {:ok, %{
          "id" => "ag_123",
          "name" => "New Name",
          "model" => "claude-sonnet-4",
          "system_prompt" => "Test",
          "tools" => [],
          "temperature" => 0.5
        }}
      end)

      {:ok, updated} = Agent.update(agent, name: "New Name", temperature: 0.5)

      assert updated.name == "New Name"
      assert updated.temperature == 0.5
    end

    test "returns error for agent without ID" do
      agent = Agent.new(name: "Local", model: "test", system_prompt: "Test")

      result = Agent.update(agent, name: "New Name")
      assert {:error, _} = result
    end
  end

  describe "delete/1" do
    test "deletes agent by ID" do
      agent = %Agent{id: "ag_123", name: "To Delete", model: "claude-sonnet-4", system_prompt: "Test", tools: [], temperature: 0.7}

      expect(Clawbreaker.ClientMock, :delete, fn "/v1/agents/ag_123", _opts ->
        {:ok, %{"deleted" => true}}
      end)

      result = Agent.delete(agent)
      assert {:ok, _} = result
    end
  end

  describe "test/2" do
    test "tests agent with single message" do
      agent = %Agent{id: "ag_123", name: "Test", model: "claude-sonnet-4", system_prompt: "Test", tools: [], temperature: 0.7}

      expect(Clawbreaker.ClientMock, :post, fn "/v1/agents/ag_123/test", body, _opts ->
        assert body.messages == [%{role: "user", content: "Hello!"}]

        {:ok, %{
          "content" => "Hi there! How can I help?",
          "tool_calls" => []
        }}
      end)

      {:ok, response} = Agent.test(agent, "Hello!")

      assert response["content"] == "Hi there! How can I help?"
    end

    test "tests agent with message history" do
      agent = %Agent{id: "ag_123", name: "Test", model: "claude-sonnet-4", system_prompt: "Test", tools: [], temperature: 0.7}

      messages = [
        %{role: "user", content: "Hi"},
        %{role: "assistant", content: "Hello!"},
        %{role: "user", content: "How are you?"}
      ]

      expect(Clawbreaker.ClientMock, :post, fn "/v1/agents/ag_123/test", body, _opts ->
        assert length(body.messages) == 3

        {:ok, %{
          "content" => "I'm doing well, thanks for asking!",
          "tool_calls" => []
        }}
      end)

      {:ok, response} = Agent.test(agent, messages)

      assert response["content"] =~ "doing well"
    end

    test "tests local agent (without ID) via different endpoint" do
      agent = Agent.new(
        name: "Local Bot",
        model: "claude-sonnet-4",
        system_prompt: "You are helpful."
      )

      expect(Clawbreaker.ClientMock, :post, fn "/v1/agents/test", body, _opts ->
        assert body.agent.name == "Local Bot"
        assert body.messages == [%{role: "user", content: "Test"}]

        {:ok, %{
          "content" => "Response from local test",
          "tool_calls" => []
        }}
      end)

      {:ok, response} = Agent.test(agent, "Test")

      assert response["content"] == "Response from local test"
    end
  end

  describe "deploy/2" do
    test "deploys agent to staging by default" do
      agent = %Agent{id: "ag_123", name: "Test", model: "claude-sonnet-4", system_prompt: "Test", tools: [], temperature: 0.7}

      expect(Clawbreaker.ClientMock, :post, fn "/v1/agents/ag_123/deploy", body, _opts ->
        assert body.environment == :staging

        {:ok, %{
          "agent_id" => "ag_123",
          "environment" => "staging",
          "version" => 1,
          "endpoint" => "https://api.clawbreaker.dev/agents/ag_123"
        }}
      end)

      {:ok, deployment} = Agent.deploy(agent)

      assert deployment["environment"] == "staging"
      assert deployment["version"] == 1
    end

    test "deploys agent to production when specified" do
      agent = %Agent{id: "ag_123", name: "Test", model: "claude-sonnet-4", system_prompt: "Test", tools: [], temperature: 0.7}

      expect(Clawbreaker.ClientMock, :post, fn "/v1/agents/ag_123/deploy", body, _opts ->
        assert body.environment == :production
        assert body.note == "Production release v1"

        {:ok, %{
          "agent_id" => "ag_123",
          "environment" => "production",
          "version" => 1,
          "endpoint" => "https://api.clawbreaker.dev/agents/ag_123"
        }}
      end)

      {:ok, deployment} = Agent.deploy(agent, env: :production, note: "Production release v1")

      assert deployment["environment"] == "production"
    end
  end
end
