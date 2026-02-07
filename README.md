# Clawbreaker

[![CI](https://github.com/CloudBedrock/clawbreaker/actions/workflows/ci.yml/badge.svg)](https://github.com/CloudBedrock/clawbreaker/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/clawbreaker.svg)](https://hex.pm/packages/clawbreaker)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/clawbreaker)

Official Elixir client for [Clawbreaker](https://clawbreaker.ai) — the enterprise AI agent platform.

## Installation

Add `clawbreaker` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:clawbreaker, "~> 0.1"}
  ]
end
```

Or in Livebook:

```elixir
Mix.install([{:clawbreaker, "~> 0.1"}])
```

## Quick Start

```elixir
# Connect to Clawbreaker (opens browser for OAuth)
Clawbreaker.connect!()

# Or use API key
Clawbreaker.connect!(api_key: System.fetch_env!("CLAWBREAKER_API_KEY"))

# Create an agent
agent = Clawbreaker.Agent.create!(
  name: "Support Bot",
  model: "claude-sonnet-4",
  system_prompt: "You are a helpful customer support agent."
)

# Test it
response = Clawbreaker.Agent.test!(agent, "Hello!")
IO.puts(response["content"])

# Deploy to production
{:ok, deployment} = Clawbreaker.Agent.deploy(agent, env: :production)
```

## Features

### Agents

```elixir
# Create
agent = Clawbreaker.Agent.create!(
  name: "My Bot",
  model: "claude-sonnet-4",
  system_prompt: "You are helpful.",
  tools: [:search_kb, :create_ticket],
  temperature: 0.7
)

# List all agents
agents = Clawbreaker.Agent.list!()

# Get by ID
agent = Clawbreaker.Agent.get!("ag_123")

# Update
agent = Clawbreaker.Agent.update!(agent, temperature: 0.5)

# Delete
Clawbreaker.Agent.delete!(agent)
```

### Testing Agents

```elixir
# Simple test
response = Clawbreaker.Agent.test!(agent, "Hello!")
IO.puts(response["content"])

# With conversation history
messages = [
  %{role: "user", content: "Hi"},
  %{role: "assistant", content: "Hello!"},
  %{role: "user", content: "How are you?"}
]
response = Clawbreaker.Agent.test!(agent, messages)

# Streaming responses
Clawbreaker.Agent.stream_test(agent, "Tell me a story", fn event ->
  case event do
    {:chunk, text} -> IO.write(text)
    {:tool_call, tool} -> IO.puts("\n🔧 Calling #{tool["name"]}...")
    {:tool_result, _result} -> :ok
    :done -> IO.puts("\n✅ Done")
    _ -> :ok
  end
end)
```

### Deployment

```elixir
# Deploy to staging (default)
{:ok, deployment} = Clawbreaker.Agent.deploy(agent)

# Deploy to production
{:ok, deployment} = Clawbreaker.Agent.deploy(agent, env: :production, note: "v1.0 release")

# Deployment info
IO.puts("Endpoint: #{deployment["endpoint"]}")
IO.puts("Version: #{deployment["version"]}")
```

## Livebook Smart Cells

When used in [Livebook](https://livebook.dev), visual smart cells are automatically available:

| Cell | Description |
|------|-------------|
| 🔌 **Connect to Clawbreaker** | OAuth/API key setup |
| 🤖 **Agent Builder** | Visual agent configuration |
| 💬 **Agent Chat** | Interactive testing with streaming |
| 🚀 **Deploy Agent** | One-click deployment |

## Configuration

### Application Config

```elixir
# config/runtime.exs
config :clawbreaker,
  url: System.get_env("CLAWBREAKER_URL", "https://api.clawbreaker.ai"),
  api_key: System.get_env("CLAWBREAKER_API_KEY")
```

### Runtime Connection

```elixir
# Interactive OAuth (opens browser)
Clawbreaker.connect!()

# With API key
Clawbreaker.connect!(api_key: "sk_live_...")

# Custom instance URL
Clawbreaker.connect!(
  url: "https://clawbreaker.mycompany.com",
  api_key: "sk_..."
)

# From environment variables
# Reads CLAWBREAKER_URL and CLAWBREAKER_API_KEY
Clawbreaker.connect_from_env!()
```

## Error Handling

All functions have bang (`!`) and non-bang variants:

```elixir
# Bang version raises on error
agent = Clawbreaker.Agent.get!("ag_123")

# Non-bang returns {:ok, result} or {:error, reason}
case Clawbreaker.Agent.get("ag_123") do
  {:ok, agent} -> IO.puts("Found: #{agent.name}")
  {:error, :not_found} -> IO.puts("Agent not found")
  {:error, :unauthorized} -> IO.puts("Check your API key")
  {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
end
```

## Development

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Run linter
mix lint

# Generate docs
mix docs
```

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.
