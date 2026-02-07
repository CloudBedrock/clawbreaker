defmodule Clawbreaker.SmartCell do
  @moduledoc false

  @cells [
    Clawbreaker.SmartCell.Connection,
    Clawbreaker.SmartCell.AgentBuilder,
    Clawbreaker.SmartCell.AgentChat,
    Clawbreaker.SmartCell.Deploy
  ]

  @doc """
  Register all Clawbreaker smart cells with Kino.
  Called automatically when the application starts if Kino is available.
  """
  def register_all do
    if Code.ensure_loaded?(Kino.SmartCell) do
      Enum.each(@cells, &maybe_register/1)
    end

    :ok
  end

  defp maybe_register(cell) do
    if Code.ensure_loaded?(cell), do: Kino.SmartCell.register(cell)
  end
end
