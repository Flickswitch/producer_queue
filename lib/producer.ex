defmodule ProducerQueue.Producer do
  @moduledoc """
  A simple implementation of a GenStage producer
  """

  use GenStage

  @typedoc """
  {demand_count, queue_module, check_interval_in_ms}
  """
  @type producer_state :: {pos_integer(), atom(), pos_integer()}

  @doc """
  Start a `ProducerQueue.Producer` linked to a `ProducerQueue.Queue`
  """
  def start_link(opts \\ []), do: GenStage.start_link(__MODULE__, opts)

  @impl true
  @spec init(opts :: []) :: {:producer, producer_state()}
  def init(opts) do
    {:producer, {0, Keyword.get(opts, :queue), Keyword.get(opts, :check_interval, 500)}}
  end

  @impl true
  def handle_info(:dispatch_events, state), do: dispatch_events(state)

  @impl true
  def handle_demand(new_demand, {demand, queue, check_interval}) do
    dispatch_events({demand + new_demand, queue, check_interval})
  end

  defp dispatch_events({demand, queue, check_interval}) do
    events = ProducerQueue.Queue.pop(queue, demand)
    demand = demand - length(events)
    requeue_dispatch(events, demand, check_interval)

    {:noreply, events, {demand, queue, check_interval}}
  end

  # demand satisfied - no requeue needed
  defp requeue_dispatch(_, 0, _), do: :noop

  # run out of events to send to consumer - try to satisfy demand later
  defp requeue_dispatch([], _, check_interval) do
    Process.send_after(self(), :dispatch_events, check_interval)
  end

  # demand not satisfied and events available - try to satisfy demand immediately
  defp requeue_dispatch(_, _, _), do: send(self(), :dispatch_events)
end
