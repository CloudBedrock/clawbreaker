# Clawbreaker

Official Elixir client for [Clawbreaker](https://clawbreaker.dev) — the enterprise AI agent platform.

## Installation

```elixir
# In Livebook
Mix.install([{:clawbreaker, "~> 0.1"}])

# In mix.exs
def deps do
  [{:clawbreaker, "~> 0.1"}]
end
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

## Livebook Smart Cells

When used in Livebook, visual smart cells are automatically available:

- 🔌 **Connect to Clawbreaker** — OAuth/API key setup
- 🤖 **Agent Builder** — Visual agent configuration
- 💬 **Agent Chat** — Interactive testing with streaming
- 🚀 **Deploy Agent** — One-click deployment

## Features

### Agents

```elixir
# Create
agent = Clawbreaker.Agent.create!(name: "Bot", model: "claude-sonnet-4", ...)

# List
Clawbreaker.Agent.list!()

# Get
agent = Clawbreaker.Agent.get!("ag_123")

# Update
Clawbreaker.Agent.update!(agent, temperature: 0.5)

# Delete
Clawbreaker.Agent.delete!(agent)
```

### Testing

```elixir
# Simple test
response = Clawbreaker.Agent.test!(agent, "Hello!")

# With history
messages = [
  %{role: "user", content: "Hi"},
  %{role: "assistant", content: "Hello!"},
  %{role: "user", content: "How are you?"}
]
response = Clawbreaker.Agent.test!(agent, messages)

# Streaming
Clawbreaker.Agent.stream_test(agent, "Tell me a story", fn event ->
  case event do
    {:chunk, text} -> IO.write(text)
    {:tool_call, tool} -> IO.puts("\n🔧 #{tool["name"]}")
    :done -> IO.puts("\n✅ Done")
  end
end)
```

### Deployment

```elixir
# Deploy to staging
{:ok, deployment} = Clawbreaker.Agent.deploy(agent, env: :staging)

# Deploy to production
{:ok, deployment} = Clawbreaker.Agent.deploy(agent, env: :production)
```

## Configuration

### Application Config

```elixir
# config/runtime.exs
config :clawbreaker,
  url: System.get_env("CLAWBREAKER_URL", "https://api.clawbreaker.dev"),
  api_key: System.get_env("CLAWBREAKER_API_KEY")
```

### Runtime

```elixir
Clawbreaker.connect!(
  url: "https://api.clawbreaker.dev",
  api_key: "sk_..."
)
```

## Documentation

- [Full Documentation](https://docs.clawbreaker.dev)
- [API Reference](https://docs.clawbreaker.dev/api)
- [Guides](https://docs.clawbreaker.dev/guides)

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.
