if Code.ensure_loaded?(Kino.SmartCell) do
  defmodule Clawbreaker.SmartCell.Connection do
    @moduledoc false
    use Kino.JS
    use Kino.JS.Live
    use Kino.SmartCell, name: "Connect to Clawbreaker"

    @impl true
    def init(attrs, ctx) do
      url = attrs["url"] || "https://api.clawbreaker.ai"

      {:ok,
       assign(ctx,
         url: url,
         use_api_key: attrs["use_api_key"] || false
       )}
    end

    @impl true
    def handle_connect(ctx) do
      {:ok,
       %{
         url: ctx.assigns.url,
         use_api_key: ctx.assigns.use_api_key
       }, ctx}
    end

    @impl true
    def handle_event("update", params, ctx) do
      ctx =
        assign(ctx,
          url: params["url"] || ctx.assigns.url,
          use_api_key: params["use_api_key"] || false
        )

      broadcast_event(ctx, "update", %{
        url: ctx.assigns.url,
        use_api_key: ctx.assigns.use_api_key
      })

      {:noreply, ctx}
    end

    @impl true
    def to_attrs(ctx) do
      %{
        "url" => ctx.assigns.url,
        "use_api_key" => ctx.assigns.use_api_key
      }
    end

    @impl true
    def to_source(attrs) do
      if attrs["use_api_key"] do
        quote do
          Clawbreaker.connect!(
            url: unquote(attrs["url"]),
            api_key: System.fetch_env!("LB_CLAWBREAKER_API_KEY")
          )
        end
      else
        quote do
          Clawbreaker.connect!(url: unquote(attrs["url"]))
        end
      end
      |> Kino.SmartCell.quoted_to_string()
    end

    asset "main.js" do
      """
      export function init(ctx, payload) {
        ctx.importCSS("main.css");

        ctx.root.innerHTML = `
          <div class="clawbreaker-connection">
            <div class="header">
              <span class="icon">🔌</span>
              <span class="title">Connect to Clawbreaker</span>
            </div>

            <div class="field">
              <label>Instance URL</label>
              <input type="url" name="url" value="${payload.url}"
                     placeholder="https://api.clawbreaker.ai" />
            </div>

            <div class="field checkbox">
              <label>
                <input type="checkbox" name="use_api_key"
                       ${payload.use_api_key ? 'checked' : ''} />
                Use API Key (from Livebook secrets)
              </label>
            </div>

            <div class="hint">
              ${payload.use_api_key
                ? 'Add CLAWBREAKER_API_KEY to your Livebook secrets'
                : 'Will open browser for OAuth authentication'}
            </div>
          </div>
        `;

        const urlInput = ctx.root.querySelector('input[name="url"]');
        const apiKeyCheckbox = ctx.root.querySelector('input[name="use_api_key"]');

        urlInput.addEventListener("change", () => {
          ctx.pushEvent("update", { url: urlInput.value });
        });

        apiKeyCheckbox.addEventListener("change", () => {
          ctx.pushEvent("update", { use_api_key: apiKeyCheckbox.checked });
        });

        ctx.handleEvent("update", (payload) => {
          urlInput.value = payload.url;
          apiKeyCheckbox.checked = payload.use_api_key;
        });
      }
      """
    end

    asset "main.css" do
      """
      .clawbreaker-connection {
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

      .field input[type="url"] {
        width: 100%;
        padding: 8px 12px;
        border: 1px solid #dee2e6;
        border-radius: 4px;
        font-size: 14px;
      }

      .field.checkbox label {
        display: flex;
        align-items: center;
        gap: 8px;
        cursor: pointer;
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
