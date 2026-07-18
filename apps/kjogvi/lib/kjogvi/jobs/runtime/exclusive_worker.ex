defmodule Kjogvi.Jobs.Runtime.ExclusiveWorker do
  @moduledoc """
  `use` this instead of `Oban.Worker` for background tasks that must hold an
  exclusive slot: at most one run per worker + identifying args at a time,
  observable through `Kjogvi.Jobs.status/2` and the
  `Kjogvi.Jobs.Runtime.Bridge` lifecycle broadcasts.

  Baked-in Oban config:

    * `max_attempts: 1` — no retries: a silent retry would double-run an
      import, so a failed or crashed job goes straight to `discarded`.
    * `unique` across the `:incomplete` states with `period: :infinity` —
      inserting while a run is in flight returns the existing job
      (`conflict?: true`) instead of enqueuing a second one, and a finished
      run frees the slot. Pass `unique_keys: [:user_id]` to key the slot on
      specific args; without it the whole args map identifies it.
    * `queue: :imports` — override with `queue:`.
    * a 5-minute `timeout/1` — override the function for longer tasks.

  Report mid-run progress from `perform/1` with `Kjogvi.Jobs.progress/2`,
  passing the job itself so the report lands on the job row as well as on
  the key's PubSub topic.

  ## Example

      defmodule Kjogvi.Jobs.LegacyImport do
        use Kjogvi.Jobs.Runtime.ExclusiveWorker, unique_keys: [:user_id]

        @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
        def pubsub_key(%Oban.Job{args: %{"user_id" => user_id}}) do
          {:legacy_import, user_id}
        end

        @impl Oban.Worker
        def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
          # ...
        end
      end
  """

  @doc """
  The task key identifying the job's exclusive slot, e.g. `{:legacy_import, 7}`.

  `Kjogvi.Util.PubSubTopic.for_key/1` turns it into the topic the job's
  lifecycle events are broadcast on; subscribers derive their topic from the
  same key, so the two can't drift apart.
  """
  @callback pubsub_key(Oban.Job.t()) :: term()

  @doc """
  The loading message shown while the job runs. Defaults to `"In progress..."`.
  """
  @callback start_message(Oban.Job.t()) :: String.t()

  defmacro __using__(opts) do
    {unique_keys, opts} = Keyword.pop(opts, :unique_keys, [])

    unique = [period: :infinity, states: :incomplete]
    unique = if unique_keys == [], do: unique, else: Keyword.put(unique, :keys, unique_keys)

    opts =
      opts
      |> Keyword.put_new(:queue, :imports)
      |> Keyword.put_new(:max_attempts, 1)
      |> Keyword.put(:unique, unique)

    quote do
      use Oban.Worker, unquote(opts)

      @behaviour Kjogvi.Jobs.Runtime.ExclusiveWorker

      @impl Oban.Worker
      def timeout(_job), do: :timer.minutes(5)

      @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
      def start_message(_job), do: "In progress..."

      defoverridable timeout: 1, start_message: 1
    end
  end
end
