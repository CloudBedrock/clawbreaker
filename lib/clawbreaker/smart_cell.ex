defmodule Clawbreaker.SmartCell do
  @moduledoc false

  @doc """
  Register all Clawbreaker smart cells with Kino.
  Called automatically when the application starts if Kino is available.
  """
  def register_all do
    if Code.ensure_loaded?(Kino.SmartCell) do
      cells = [
        Clawbreaker.SmartCell.Connection,
        Clawbreaker.SmartCell.AgentBuilder,
        Clawbreaker.SmartCell.AgentChat,
        Clawbreaker.SmartCell.Deploy
      ]

      for cell <- cells do
        if Code.ensure_loaded?(cell) do
          Kino.SmartCell.register(cell)
        end
      end
    end

    :ok
  end
end
