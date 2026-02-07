defmodule ClawbreakerTest do
  use ExUnit.Case, async: true

  describe "connect/1" do
    test "configures with api_key" do
      assert {:ok, _} = Clawbreaker.connect(api_key: "test_key", persist: false)
      assert Clawbreaker.connected?()
    end

    test "returns error without credentials" do
      Clawbreaker.disconnect()
      refute Clawbreaker.connected?()
    end
  end
end

defmodule Clawbreaker.AgentTest do
  use ExUnit.Case, async: true

  alias Clawbreaker.Agent

  describe "new/1" do
    test "creates local agent struct" do
      agent = Agent.new(
        name: "Test Bot",
        model: "claude-sonnet-4",
        system_prompt: "You are helpful."
      )

      assert %Agent{} = agent
      assert agent.name == "Test Bot"
      assert agent.model == "claude-sonnet-4"
      assert agent.temperature == 0.7
    end

    test "requires name, model, system_prompt" do
      assert_raise KeyError, fn ->
        Agent.new(name: "Test")
      end
    end
  end
end
