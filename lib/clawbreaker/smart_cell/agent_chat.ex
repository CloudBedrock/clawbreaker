if Code.ensure_loaded?(Kino.SmartCell) do
  defmodule Clawbreaker.SmartCell.AgentChat do
    @moduledoc false
    use Kino.JS
    use Kino.JS.Live
    use Kino.SmartCell, name: "Agent Chat"

    @impl true
    def init(attrs, ctx) do
      {:ok,
       assign(ctx,
         agent_var: attrs["agent_var"] || "agent"
       )}
    end

    @impl true
    def handle_connect(ctx) do
      {:ok, %{agent_var: ctx.assigns.agent_var}, ctx}
    end

    @impl true
    def handle_event("update", %{"agent_var" => var}, ctx) do
      {:noreply, assign(ctx, agent_var: var)}
    end

    @impl true
    def to_attrs(ctx) do
      %{"agent_var" => ctx.assigns.agent_var}
    end

    @impl true
    def to_source(attrs) do
      var = String.to_atom(attrs["agent_var"])

      quote do
        Kino.nothing()

        # Interactive chat widget
        chat = Clawbreaker.Chat.new(unquote(Macro.var(var, nil)))
      end
      |> Kino.SmartCell.quoted_to_string()
    end

    asset "main.js" do
      """
      export function init(ctx, payload) {
        ctx.importCSS("main.css");

        ctx.root.innerHTML = `
          <div class="agent-chat-config">
            <div class="header">
              <span class="icon">💬</span>
              <span class="title">Agent Chat</span>
            </div>

            <div class="field">
              <label>Agent Variable</label>
              <input type="text" name="agent_var" value="${payload.agent_var}"
                     placeholder="agent" />
            </div>

            <div class="hint">
              Run this cell to start an interactive chat with your agent.
            </div>
          </div>
        `;

        ctx.root.querySelector('[name="agent_var"]').addEventListener('change', (e) => {
          ctx.pushEvent("update", { agent_var: e.target.value });
        });
      }
      """
    end

    asset "main.css" do
      """
      .agent-chat-config {
        font-family: system-ui, -apple-system, sans-serif;
        padding: 16px;
        background: #f8f9fa;
        border-radius: 8px;
      }

      .header {
        display: flex;
        align-items: center;
        gap: 8px;
        margin-bottom: 16px;
        font-weight: 600;
      }

      .icon { font-size: 20px; }
      .title { font-size: 14px; }

      .field {
        margin-bottom: 12px;
      }

      .field label {
        display: block;
        font-size: 12px;
        font-weight: 500;
        margin-bottom: 4px;
        color: #495057;
      }

      .field input {
        width: 200px;
        padding: 8px 12px;
        border: 1px solid #dee2e6;
        border-radius: 4px;
        font-size: 14px;
        font-family: monospace;
      }

      .hint {
        font-size: 12px;
        color: #6c757d;
        font-style: italic;
      }
      """
    end
  end
end
