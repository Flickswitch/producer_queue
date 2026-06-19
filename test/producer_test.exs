defmodule ProducerQueue.ProducerTest do
  use ExUnit.Case

  alias ProducerQueue.Producer
  alias ProducerQueue.Queue
  alias ProducerQueue.TestConsumer

  setup do
    {:ok, queue} = Queue.start_link()
    [state: %Producer{queue: queue, check_interval: 10}, queue: queue]
  end

  test "handle zero demand with zero backlog", %{state: state} do
    assert {:noreply, [], ^state} = Producer.handle_demand(0, state)
    refute_receive :dispatch_events
  end

  test "handle demand with zero backlog", %{
    state: %Producer{check_interval: check_interval} = state,
    queue: queue
  } do
    :ok = Queue.push(queue, ~c"123")
    expected_state = %Producer{queue: queue, check_interval: check_interval}

    assert {:noreply, ~c"123", ^expected_state} = Producer.handle_demand(3, state)
    assert Queue.pop(queue) == []
    refute_receive :dispatch_events
  end

  test "handle demand with backlog - basic", %{
    state: %Producer{check_interval: check_interval} = state,
    queue: queue
  } do
    :ok = Queue.push(queue, ~c"12")

    assert {:noreply, ~c"12",
            %Producer{demand: 1, queue: ^queue, check_interval: ^check_interval, timer: timer}} =
             Producer.handle_demand(3, state)

    assert is_reference(timer)
    assert Queue.pop(queue) == []
    assert_receive :dispatch_events
  end

  test "handle demand with backlog", %{
    state: %Producer{check_interval: check_interval},
    queue: queue
  } do
    :ok = Queue.push(queue, ~c"12")
    {:ok, producer} = Producer.start_link(check_interval: 10, queue: queue)
    {:ok, consumer} = TestConsumer.start_link(producer)

    Process.sleep(check_interval)
    assert TestConsumer.get_events_count(consumer) == 2

    :ok = Queue.push(queue, ~c"3")
    Process.sleep(check_interval * 2)

    assert TestConsumer.get_events_count(consumer) == 3
  end

  describe "prepare_for_draining/1" do
    test "flushes the entire queue in FIFO order when enabled", %{queue: queue} do
      state = %Producer{queue: queue, check_interval: 10, drain_on_shutdown: true}
      backlog = Enum.to_list(1..2_500)
      :ok = Queue.push(queue, backlog)

      assert {:noreply, ^backlog, %Producer{demand: 0, timer: nil, drain_on_shutdown: true}} =
               Producer.prepare_for_draining(state)

      assert Queue.pop(queue, 1) == []
    end

    test "is a no-op when not enabled, leaving the queue intact", %{state: state, queue: queue} do
      :ok = Queue.push(queue, [1, 2, 3])

      assert {:noreply, [], ^state} = Producer.prepare_for_draining(state)
      assert Queue.pop(queue, 3) == [1, 2, 3]
    end

    test "cancels a pending dispatch timer while draining", %{queue: queue} do
      timer = Process.send_after(self(), :dispatch_events, 60_000)
      state = %Producer{queue: queue, check_interval: 10, timer: timer, drain_on_shutdown: true}

      assert {:noreply, [], %Producer{timer: nil}} = Producer.prepare_for_draining(state)
      assert Process.cancel_timer(timer) == false
    end
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
