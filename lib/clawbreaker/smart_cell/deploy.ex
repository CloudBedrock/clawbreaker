if Code.ensure_loaded?(Kino.SmartCell) do
  defmodule Clawbreaker.SmartCell.Deploy do
    @moduledoc false
    use Kino.JS
    use Kino.JS.Live
    use Kino.SmartCell, name: "Deploy Agent"

    @impl true
    def init(attrs, ctx) do
      {:ok,
       assign(ctx,
         agent_var: attrs["agent_var"] || "agent",
         environment: attrs["environment"] || "staging"
       )}
    end

    @impl true
    def handle_connect(ctx) do
      {:ok,
       %{
         agent_var: ctx.assigns.agent_var,
         environment: ctx.assigns.environment
       }, ctx}
    end

    @impl true
    def handle_event("update", params, ctx) do
      ctx =
        assign(ctx,
          agent_var: params["agent_var"] || ctx.assigns.agent_var,
          environment: params["environment"] || ctx.assigns.environment
        )

      {:noreply, ctx}
    end

    @impl true
    def to_attrs(ctx) do
      %{
        "agent_var" => ctx.assigns.agent_var,
        "environment" => ctx.assigns.environment
      }
    end

    @impl true
    def to_source(attrs) do
      var = String.to_atom(attrs["agent_var"])
      env = String.to_atom(attrs["environment"])

      quote do
        {:ok, deployment} =
          Clawbreaker.Agent.deploy(unquote(Macro.var(var, nil)), env: unquote(env))

        IO.puts("""
        ✅ Agent deployed!

        📍 Environment: #{deployment["environment"]}
        🆔 Agent ID: #{deployment["agent_id"]}
        📌 Version: #{deployment["version"]}
        🔗 Endpoint: #{deployment["endpoint"]}
        """)

        deployment
      end
      |> Kino.SmartCell.quoted_to_string()
    end

    asset "main.js" do
      """
      export function init(ctx, payload) {
        ctx.importCSS("main.css");

        ctx.root.innerHTML = `
          <div class="deploy-config">
            <div class="header">
              <span class="icon">🚀</span>
              <span class="title">Deploy Agent</span>
            </div>

            <div class="field">
              <label>Agent Variable</label>
              <input type="text" name="agent_var" value="${payload.agent_var}" />
            </div>

            <div class="field">
              <label>Environment</label>
              <div class="radio-group">
                <label>
                  <input type="radio" name="environment" value="staging"
                         ${payload.environment === 'staging' ? 'checked' : ''} />
                  Staging
                </label>
                <label>
                  <input type="radio" name="environment" value="production"
                         ${payload.environment === 'production' ? 'checked' : ''} />
                  Production
                </label>
              </div>
            </div>

            ${payload.environment === 'production' ? `
              <div class="warning">
                ⚠️ This will deploy to <strong>production</strong>
              </div>
            ` : ''}
          </div>
        `;

        ctx.root.querySelector('[name="agent_var"]').addEventListener('change', (e) => {
          ctx.pushEvent("update", { agent_var: e.target.value });
        });

        ctx.root.querySelectorAll('[name="environment"]').forEach(radio => {
          radio.addEventListener('change', (e) => {
            ctx.pushEvent("update", { environment: e.target.value });
          });
        });
      }
      """
    end

    asset "main.css" do
      """
      .deploy-config {
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
        margin-bottom: 16px;
      }

      .field label {
        display: block;
        font-size: 12px;
        font-weight: 500;
        margin-bottom: 4px;
        color: #495057;
      }

      .field input[type="text"] {
        width: 200px;
        padding: 8px 12px;
        border: 1px solid #dee2e6;
        border-radius: 4px;
        font-size: 14px;
        font-family: monospace;
      }

      .radio-group {
        display: flex;
        gap: 16px;
      }

      .radio-group label {
        display: flex;
        align-items: center;
        gap: 4px;
        cursor: pointer;
      }

      .warning {
        padding: 8px 12px;
        background: #fff3cd;
        border: 1px solid #ffc107;
        border-radius: 4px;
        font-size: 12px;
      }
      """
    end
  end
end
