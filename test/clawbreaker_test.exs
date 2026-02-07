defmodule ClawbreakerTest do
  use ExUnit.Case, async: false

  setup do
    # Clear any existing config between tests
    Clawbreaker.disconnect()
    :ok
  end

  describe "connect/1" do
    test "configures with api_key" do
      assert {:ok, config} = Clawbreaker.connect(api_key: "test_key", persist: false)
      assert config.api_key == "test_key"
      assert Clawbreaker.connected?()
    end

    test "uses default URL when not specified" do
      {:ok, config} = Clawbreaker.connect(api_key: "test_key", persist: false)
      assert config.url == "https://api.clawbreaker.dev"
    end

    test "uses custom URL when specified" do
      {:ok, config} =
        Clawbreaker.connect(
          api_key: "test_key",
          url: "https://custom.example.com",
          persist: false
        )

      assert config.url == "https://custom.example.com"
    end
  end

  describe "connected?/0" do
    test "returns false when not connected" do
      refute Clawbreaker.connected?()
    end

    test "returns true when connected" do
      Clawbreaker.connect!(api_key: "test_key", persist: false)
      assert Clawbreaker.connected?()
    end
  end

  describe "disconnect/0" do
    test "clears connection state" do
      Clawbreaker.connect!(api_key: "test_key", persist: false)
      assert Clawbreaker.connected?()

      Clawbreaker.disconnect()
      refute Clawbreaker.connected?()
    end
  end
end

defmodule Clawbreaker.AgentTest do
  use ExUnit.Case, async: true

  alias Clawbreaker.Agent

  describe "new/1" do
    test "creates local agent struct with required fields" do
      agent =
        Agent.new(
          name: "Test Bot",
          model: "claude-sonnet-4",
          system_prompt: "You are helpful."
        )

      assert %Agent{} = agent
      assert agent.name == "Test Bot"
      assert agent.model == "claude-sonnet-4"
      assert agent.system_prompt == "You are helpful."
      assert agent.id == nil
    end

    test "uses default temperature of 0.7" do
      agent =
        Agent.new(
          name: "Test",
          model: "claude-sonnet-4",
          system_prompt: "Test"
        )

      assert agent.temperature == 0.7
    end

    test "allows custom temperature" do
      agent =
        Agent.new(
          name: "Test",
          model: "claude-sonnet-4",
          system_prompt: "Test",
          temperature: 0.5
        )

      assert agent.temperature == 0.5
    end

    test "uses empty tools list by default" do
      agent =
        Agent.new(
          name: "Test",
          model: "claude-sonnet-4",
          system_prompt: "Test"
        )

      assert agent.tools == []
    end

    test "allows specifying tools" do
      agent =
        Agent.new(
          name: "Test",
          model: "claude-sonnet-4",
          system_prompt: "Test",
          tools: [:search, :calculator]
        )

      assert agent.tools == [:search, :calculator]
    end

    test "raises KeyError when name is missing" do
      assert_raise KeyError, ~r/key :name not found/, fn ->
        Agent.new(model: "claude-sonnet-4", system_prompt: "Test")
      end
    end

    test "raises KeyError when model is missing" do
      assert_raise KeyError, ~r/key :model not found/, fn ->
        Agent.new(name: "Test", system_prompt: "Test")
      end
    end

    test "raises KeyError when system_prompt is missing" do
      assert_raise KeyError, ~r/key :system_prompt not found/, fn ->
        Agent.new(name: "Test", model: "claude-sonnet-4")
      end
    end
  end

  describe "struct" do
    test "has expected fields" do
      agent = %Agent{}

      assert Map.has_key?(agent, :id)
      assert Map.has_key?(agent, :name)
      assert Map.has_key?(agent, :model)
      assert Map.has_key?(agent, :system_prompt)
      assert Map.has_key?(agent, :tools)
      assert Map.has_key?(agent, :temperature)
      assert Map.has_key?(agent, :metadata)
    end
  end
end

defmodule Clawbreaker.ErrorsTest do
  use ExUnit.Case, async: true

  describe "ConnectionError" do
    test "accepts string message" do
      error = Clawbreaker.ConnectionError.exception("test error")
      assert error.message == "test error"
    end

    test "handles timeout atom" do
      error = Clawbreaker.ConnectionError.exception(:timeout)
      assert error.message == "Connection timed out"
    end

    test "inspects unknown terms" do
      error = Clawbreaker.ConnectionError.exception({:unexpected, :value})
      assert error.message == "{:unexpected, :value}"
    end
  end

  describe "APIError" do
    test "handles unauthorized atom" do
      error = Clawbreaker.APIError.exception(:unauthorized)
      assert error.status == 401
      assert error.message =~ "Unauthorized"
    end

    test "handles not_found atom" do
      error = Clawbreaker.APIError.exception(:not_found)
      assert error.status == 404
      assert error.message == "Resource not found"
    end

    test "extracts message from error body" do
      error =
        Clawbreaker.APIError.exception(%{
          status: 400,
          body: %{"error" => %{"message" => "Invalid request"}}
        })

      assert error.status == 400
      assert error.message == "Invalid request"
    end

    test "extracts simple error string from body" do
      error =
        Clawbreaker.APIError.exception(%{
          status: 400,
          body: %{"error" => "Something went wrong"}
        })

      assert error.message == "Something went wrong"
    end

    test "falls back to status message when no error in body" do
      error =
        Clawbreaker.APIError.exception(%{
          status: 500,
          body: %{"unexpected" => "format"}
        })

      assert error.message == "API request failed with status 500"
    end
  end
end

defmodule Clawbreaker.ConfigTest do
  use ExUnit.Case, async: false

  alias Clawbreaker.Config

  setup do
    Config.clear()
    :ok
  end

  describe "default_url/0" do
    test "returns the default API URL" do
      assert Config.default_url() == "https://api.clawbreaker.dev"
    end
  end

  describe "configure/1" do
    test "stores configuration" do
      {:ok, config} =
        Config.configure(url: "https://test.com", api_key: "key123", persist: false)

      assert config.url == "https://test.com"
      assert config.api_key == "key123"
    end

    test "uses default URL when not specified" do
      {:ok, config} = Config.configure(api_key: "key123", persist: false)
      assert config.url == "https://api.clawbreaker.dev"
    end
  end

  describe "configured?/0" do
    test "returns false when no api_key" do
      refute Config.configured?()
    end

    test "returns false when api_key is empty string" do
      Config.configure(api_key: "", persist: false)
      refute Config.configured?()
    end

    test "returns true when api_key is set" do
      Config.configure(api_key: "valid_key", persist: false)
      assert Config.configured?()
    end
  end

  describe "get/0 and get/1" do
    test "returns full config map" do
      Config.configure(url: "https://test.com", api_key: "key", persist: false)

      config = Config.get()
      assert is_map(config)
      assert config.url == "https://test.com"
      assert config.api_key == "key"
    end

    test "returns specific key" do
      Config.configure(api_key: "mykey", persist: false)

      assert Config.get(:api_key) == "mykey"
      assert Config.get(:url) == "https://api.clawbreaker.dev"
    end
  end

  describe "clear/0" do
    test "removes all configuration" do
      Config.configure(api_key: "key", persist: false)
      assert Config.configured?()

      Config.clear()
      refute Config.configured?()
    end
  end
end
