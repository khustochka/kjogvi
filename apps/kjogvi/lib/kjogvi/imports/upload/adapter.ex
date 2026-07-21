defmodule Kjogvi.Imports.Upload.Adapter do
  @moduledoc """
  Storage backend for temporary import uploads (see `Kjogvi.Imports.Upload`).

  `config` is the full `Kjogvi.Imports.Upload` config keyword list; each
  adapter reads its own keys from it.
  """

  @callback configured?(config :: keyword()) :: boolean()

  @callback write(config :: keyword(), key :: String.t(), content :: iodata()) ::
              :ok | {:error, term()}

  @callback fetch_to(config :: keyword(), key :: String.t(), local_path :: String.t()) ::
              :ok | {:error, term()}

  @callback delete(config :: keyword(), key :: String.t()) ::
              :ok | {:error, term()}
end
