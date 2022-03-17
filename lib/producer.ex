defmodule ProducerQueue.Producer do
  @moduledoc """
  A simple implementation of a GenStage producer
  """

  use GenStage

  @typedoc """
  State for the producer: {demand, queue_module, check_interval}
  """
  @type producer_state :: {pos_integer(), atom(), pos_integer()}

  @doc """
  Start a `ProducerQueue.Producer` linked to a `ProducerQueue.Queue`
  """
  @impl true
  def start_link(opts \\ []), do: GenStage.start_link(__MODULE__, opts)

  @impl true
  def init(opts) do
    {:producer, {0, Keyword.get(opts, :queue), Keyword.get(opts, :check_interval, 100)}}
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

  defp requeue_dispatch([], _, check_interval) do
    Process.send_after(self(), :dispatch_events, check_interval)
  end

  defp requeue_dispatch(_, 0, _), do: :noop
  defp requeue_dispatch(_, _, _), do: Process.send_after(self(), :dispatch_events, 0)
end
