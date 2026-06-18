defmodule ProducerQueue.Producer do
  @moduledoc """
  A simple implementation of a GenStage producer backed by a `ProducerQueue.Queue`.

  ## Draining on shutdown

  Pass `drain_on_shutdown: true` to opt in to flushing the linked queue into the
  pipeline when the producer is asked to drain. Under Broadway this happens on
  graceful shutdown (SIGTERM/releases): Broadway invokes `prepare_for_draining/1`
  before stopping the producer, giving us the chance to emit whatever is still
  buffered in the queue so it is processed instead of lost.

  Note this only protects against *graceful* shutdown - a SIGKILL/OOM still drops
  the in-memory queue.

  Broadway detects `prepare_for_draining/1` via `function_exported?/3`, so no
  `Broadway.Producer` behaviour (or compile-time Broadway dependency) is required.

  When draining is enabled the GenStage `:buffer_size` defaults to `:infinity`. In steady state
  the producer only ever emits exactly the demand it was handed, so the buffer
  sits empty regardless of the cap - the cap is a limit, not an allocation.
  Draining consumers should override `:buffer_size` to comfortably exceed their
  worst-case queue depth at shutdown.
  """

  use GenStage

  defstruct demand: 0, queue: nil, check_interval: 500, timer: nil, drain_on_shutdown: false

  @type t :: %__MODULE__{
          demand: non_neg_integer(),
          queue: atom() | pid() | nil,
          check_interval: pos_integer(),
          timer: nil | reference(),
          drain_on_shutdown: boolean()
        }

  @drain_chunk_size 500

  @doc """
  Start a `ProducerQueue.Producer` linked to a `ProducerQueue.Queue`.

  Options:
    * `:queue` - the queue to pull from (required)
    * `:check_interval` - ms between dispatch attempts when demand is unmet (default 500)
    * `:drain_on_shutdown` - flush the queue into the pipeline on graceful shutdown (default false)
    * `:buffer_size` - GenStage producer buffer (default 100_000 when draining, else GenStage default)
  """
  def start_link(opts \\ []), do: GenStage.start_link(__MODULE__, opts)

  @impl true
  @spec init(opts :: keyword()) :: {:producer, t(), keyword()}
  def init(opts) do
    drain? = Keyword.get(opts, :drain_on_shutdown, false)

    state = %__MODULE__{
      queue: Keyword.get(opts, :queue),
      check_interval: Keyword.get(opts, :check_interval, 500),
      drain_on_shutdown: drain?
    }

    {:producer, state, buffer_size: buffer_size(opts, drain?)}
  end

  @impl true
  def handle_info(:dispatch_events, %__MODULE__{timer: nil} = state) do
    {:noreply, [], state}
  end

  def handle_info(:dispatch_events, state) do
    dispatch_events(%{state | timer: nil})
  end

  @impl true
  def handle_demand(new_demand, %__MODULE__{demand: demand} = state) do
    dispatch_events(%{state | demand: demand + new_demand})
  end

  @doc """
  Invoked by Broadway right before draining on graceful shutdown. When
  `drain_on_shutdown` is enabled, flush everything still in the queue into the
  pipeline so it is processed before the producer stops. Otherwise it is a no-op.
  """
  def prepare_for_draining(%__MODULE__{drain_on_shutdown: true} = state) do
    if state.timer, do: Process.cancel_timer(state.timer)
    {:noreply, drain_queue(state.queue), %{state | demand: 0, timer: nil}}
  end

  def prepare_for_draining(state), do: {:noreply, [], state}

  defp dispatch_events(%__MODULE__{timer: nil} = state) do
    events = ProducerQueue.Queue.pop(state.queue, state.demand)
    demand = state.demand - length(events)
    timer = requeue_dispatch(events, demand, state.check_interval)

    {:noreply, events, %{state | demand: demand, timer: timer}}
  end

  # this prevents dispatch requeue until the previous dispatch_events message is received
  defp dispatch_events(state), do: {:noreply, [], state}

  # demand satisfied - no requeue needed
  defp requeue_dispatch(_, 0, _), do: nil

  # run out of events to send to consumer - try to satisfy demand later
  defp requeue_dispatch([], _, check_interval) do
    Process.send_after(self(), :dispatch_events, check_interval)
  end

  # demand not satisfied and events available - try to satisfy demand immediately
  defp requeue_dispatch(_, _, _), do: Process.send_after(self(), :dispatch_events, 0)

  # Pop the whole queue in FIFO order, in bounded chunks.
  defp drain_queue(queue), do: queue |> drain_chunks([]) |> Enum.concat()

  defp drain_chunks(queue, acc) do
    case ProducerQueue.Queue.pop(queue, @drain_chunk_size) do
      [] -> Enum.reverse(acc)
      events -> drain_chunks(queue, [events | acc])
    end
  end

  defp buffer_size(opts, true), do: Keyword.get(opts, :buffer_size, :infinity)
  defp buffer_size(opts, false), do: Keyword.get(opts, :buffer_size, 10_000)
end
