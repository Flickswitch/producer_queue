defmodule ProducerQueue.Producer do
  @moduledoc """
  A simple implementation of a GenStage producer
  """

  use GenStage

  @typedoc """
  {demand_count, queue_module, check_interval_in_ms, timer}
  """
  @type producer_state :: {pos_integer(), atom(), pos_integer(), nil | reference()}

  @doc """
  Start a `ProducerQueue.Producer` linked to a `ProducerQueue.Queue`
  """
  def start_link(opts \\ []), do: GenStage.start_link(__MODULE__, opts)

  @impl true
  @spec init(opts :: []) :: {:producer, producer_state()}
  def init(opts) do
    state = {0, Keyword.get(opts, :queue), Keyword.get(opts, :check_interval, 500), nil}
    {:producer, state}
  end

  @impl true
  def handle_info(:dispatch_events, {_, _, _, nil} = state) do
    {:noreply, [], state}
  end

  def handle_info(:dispatch_events, {demand, queue, check_interval, _}) do
    dispatch_events({demand, queue, check_interval, nil})
  end

  @impl true
  def handle_demand(new_demand, {demand, queue, check_interval, timer}) do
    dispatch_events({demand + new_demand, queue, check_interval, timer})
  end

  defp dispatch_events({demand, queue, check_interval, nil}) do
    events = ProducerQueue.Queue.pop(queue, demand)
    demand = demand - length(events)
    timer = requeue_dispatch(events, demand, check_interval)

    {:noreply, events, {demand, queue, check_interval, timer}}
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
end
