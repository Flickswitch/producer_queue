defmodule ProducerQueue.ProducerTest do
  use ExUnit.Case

  alias ProducerQueue.Producer
  alias ProducerQueue.Queue
  alias ProducerQueue.TestConsumer

  setup do
    {:ok, queue} = Queue.start_link()
    [state: {0, queue, 10, nil}, queue: queue]
  end

  test "handle zero demand with zero backlog", %{state: state} do
    assert {:noreply, [], ^state} = Producer.handle_demand(0, state)
    refute_receive :dispatch_events
  end

  test "handle demand with zero backlog", %{state: {_, queue, check_interval, _} = state} do
    :ok = Queue.push(queue, '123')
    expected_state = {0, queue, check_interval, nil}

    assert {:noreply, '123', ^expected_state} = Producer.handle_demand(3, state)
    assert Queue.pop(queue) == []
    refute_receive :dispatch_events
  end

  test "handle demand with backlog - basic", %{state: {_, queue, check_interval, _} = state} do
    :ok = Queue.push(queue, '12')

    assert {:noreply, '12', {1, ^queue, ^check_interval, timer}} =
             Producer.handle_demand(3, state)

    assert is_reference(timer)
    assert Queue.pop(queue) == []
    assert_receive :dispatch_events
  end

  test "handle demand with backlog", %{state: {_, queue, check_interval, _}} do
    :ok = Queue.push(queue, '12')
    {:ok, producer} = Producer.start_link(check_interval: 10, queue: queue)
    {:ok, consumer} = TestConsumer.start_link(producer)

    Process.sleep(check_interval)
    assert TestConsumer.get_events_count(consumer) == 2

    :ok = Queue.push(queue, '3')
    Process.sleep(check_interval * 2)

    assert TestConsumer.get_events_count(consumer) == 3
  end
end

defmodule ProducerQueue.TestConsumer do
  use GenStage

  def start_link(producer), do: GenStage.start_link(__MODULE__, producer)

  def init(producer), do: {:consumer, 0, subscribe_to: [{producer, max_demand: 3}]}

  def get_events_count(pid), do: GenStage.call(pid, :get_events_count)

  def handle_call(:get_events_count, _from, events_count) do
    {:reply, events_count, [], events_count}
  end

  def handle_events(events, _from, events_count) do
    {:noreply, [], events_count + length(events)}
  end
end
