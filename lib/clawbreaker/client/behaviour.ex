defmodule Clawbreaker.Client.Behaviour do
  @moduledoc false

  @callback get(String.t(), keyword()) :: {:ok, map() | list()} | {:error, term()}
  @callback post(String.t(), map(), keyword()) :: {:ok, map() | list()} | {:error, term()}
  @callback put(String.t(), map(), keyword()) :: {:ok, map() | list()} | {:error, term()}
  @callback delete(String.t(), keyword()) :: {:ok, map() | list()} | {:error, term()}
end
