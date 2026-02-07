if Code.ensure_loaded?(Kino.SmartCell) do
  defmodule Clawbreaker.SmartCell.AgentBuilder do
    @moduledoc false
    use Kino.JS
    use Kino.JS.Live
    use Kino.SmartCell, name: "Clawbreaker Agent"

    @impl true
    def init(attrs, ctx) do
      {:ok,
       assign(ctx,
         name: attrs["name"] || "",
         model: attrs["model"] || "claude-sonnet-4",
         system_prompt: attrs["system_prompt"] || "",
         tools: attrs["tools"] || [],
         temperature: attrs["temperature"] || 0.7
       )}
    end

    @impl true
    def handle_connect(ctx) do
      # Fetch available models and tools from API
      models = fetch_models()
      tools = fetch_tools()

      {:ok,
       %{
         name: ctx.assigns.name,
         model: ctx.assigns.model,
         system_prompt: ctx.assigns.system_prompt,
         tools: ctx.assigns.tools,
         temperature: ctx.assigns.temperature,
         available_models: models,
         available_tools: tools
       }, ctx}
    end

    @impl true
    def handle_event("update", params, ctx) do
      ctx =
        assign(ctx,
          name: params["name"] || ctx.assigns.name,
          model: params["model"] || ctx.assigns.model,
          system_prompt: params["system_prompt"] || ctx.assigns.system_prompt,
          tools: params["tools"] || ctx.assigns.tools,
          temperature: params["temperature"] || ctx.assigns.temperature
        )

      {:noreply, ctx}
    end

    @impl true
    def to_attrs(ctx) do
      %{
        "name" => ctx.assigns.name,
        "model" => ctx.assigns.model,
        "system_prompt" => ctx.assigns.system_prompt,
        "tools" => ctx.assigns.tools,
        "temperature" => ctx.assigns.temperature
      }
    end

    @impl true
    def to_source(attrs) do
      tools =
        attrs["tools"]
        |> List.wrap()
        |> Enum.map(&String.to_atom/1)

      quote do
        agent =
          Clawbreaker.Agent.new(
            name: unquote(attrs["name"]),
            model: unquote(attrs["model"]),
            system_prompt: unquote(attrs["system_prompt"]),
            tools: unquote(tools),
            temperature: unquote(attrs["temperature"])
          )
      end
      |> Kino.SmartCell.quoted_to_string()
    end

    defp fetch_models do
      if Clawbreaker.connected?() do
        case Clawbreaker.Client.get("/v1/models") do
          {:ok, %{"data" => models}} -> models
          _ -> default_models()
        end
      else
        default_models()
      end
    end

    defp fetch_tools do
      if Clawbreaker.connected?() do
        case Clawbreaker.Client.get("/v1/tools") do
          {:ok, %{"data" => tools}} -> tools
          _ -> []
        end
      else
        []
      end
    end

    defp default_models do
      [
        %{"id" => "claude-sonnet-4", "name" => "Claude Sonnet 4"},
        %{"id" => "claude-opus-4", "name" => "Claude Opus 4"},
        %{"id" => "gpt-4o", "name" => "GPT-4o"},
        %{"id" => "gpt-4o-mini", "name" => "GPT-4o Mini"}
      ]
    end

    asset "main.js" do
      """
      export function init(ctx, payload) {
        ctx.importCSS("main.css");
        
        ctx.root.innerHTML = `
          <div class="agent-builder">
            <div class="header">
              <span class="icon">🤖</span>
              <span class="title">Agent Builder</span>
            </div>
            
            <div class="field">
              <label>Name</label>
              <input type="text" name="name" value="${payload.name}" 
                     placeholder="My Agent" />
            </div>
            
            <div class="field">
              <label>Model</label>
              <select name="model">
                ${payload.available_models.map(m => 
                  `<option value="${m.id}" ${m.id === payload.model ? 'selected' : ''}>${m.name}</option>`
                ).join('')}
              </select>
            </div>
            
            <div class="field">
              <label>System Prompt</label>
              <textarea name="system_prompt" rows="4" 
                        placeholder="You are a helpful assistant...">${payload.system_prompt}</textarea>
            </div>
            
            <div class="field">
              <label>Tools</label>
              <div class="tools-list">
                ${payload.available_tools.length > 0 
                  ? payload.available_tools.map(t => `
                      <label class="tool-item">
                        <input type="checkbox" name="tools" value="${t.id}"
                               ${payload.tools.includes(t.id) ? 'checked' : ''} />
                        <span>${t.name}</span>
                      </label>
                    `).join('')
                  : '<span class="no-tools">No tools available. Connect first or create tools.</span>'
                }
              </div>
            </div>
            
            <div class="field">
              <label>Temperature: <span class="temp-value">${payload.temperature}</span></label>
              <input type="range" name="temperature" min="0" max="1" step="0.1" 
                     value="${payload.temperature}" />
            </div>
          </div>
        `;
        
        // Event listeners
        ctx.root.querySelectorAll('input, select, textarea').forEach(el => {
          el.addEventListener('change', () => {
            const tools = [...ctx.root.querySelectorAll('input[name="tools"]:checked')]
              .map(cb => cb.value);
            
            ctx.pushEvent("update", {
              name: ctx.root.querySelector('[name="name"]').value,
              model: ctx.root.querySelector('[name="model"]').value,
              system_prompt: ctx.root.querySelector('[name="system_prompt"]').value,
              tools: tools,
              temperature: parseFloat(ctx.root.querySelector('[name="temperature"]').value)
            });
          });
        });
        
        // Update temperature display
        ctx.root.querySelector('[name="temperature"]').addEventListener('input', (e) => {
          ctx.root.querySelector('.temp-value').textContent = e.target.value;
        });
      }
      """
    end

    asset "main.css" do
      """
      .agent-builder {
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
      
      .field input[type="text"],
      .field select,
      .field textarea {
        width: 100%;
        padding: 8px 12px;
        border: 1px solid #dee2e6;
        border-radius: 4px;
        font-size: 14px;
        font-family: inherit;
      }
      
      .field textarea {
        resize: vertical;
        min-height: 80px;
      }
      
      .tools-list {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
      }
      
      .tool-item {
        display: flex;
        align-items: center;
        gap: 4px;
        padding: 4px 8px;
        background: white;
        border: 1px solid #dee2e6;
        border-radius: 4px;
        font-size: 12px;
        cursor: pointer;
      }
      
      .no-tools {
        font-size: 12px;
        color: #6c757d;
        font-style: italic;
      }
      
      input[type="range"] {
        width: 100%;
      }
      
      .temp-value {
        font-weight: normal;
        color: #6c757d;
      }
      """
    end
  end
end
