defmodule Kjogvi.Datasets.Adapter do
  @moduledoc """
  Storage backend for dataset snapshots (see `Kjogvi.Datasets`).

  `config` is the full `Kjogvi.Datasets` config keyword list; each adapter
  reads its own keys from it.
  """

  @callback write(config :: keyword(), key :: String.t(), content :: iodata()) ::
              :ok | {:error, term()}

  @callback read(config :: keyword(), key :: String.t()) ::
              {:ok, binary()} | {:error, term()}

  @callback last_modified(config :: keyword(), key :: String.t()) ::
              {:ok, DateTime.t()} | {:error, term()}
end
