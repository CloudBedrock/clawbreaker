defmodule Clawbreaker.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Clawbreaker.Config
    ]

    # Register smart cells if Kino is available
    if Code.ensure_loaded?(Kino.SmartCell) do
      Clawbreaker.SmartCell.register_all()
    end

    opts = [strategy: :one_for_one, name: Clawbreaker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
