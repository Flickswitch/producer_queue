defmodule ProducerQueue.ProducerTest do
  use ExUnit.Case

  alias ProducerQueue.Producer
  alias ProducerQueue.Queue

  setup do
    {:ok, queue} = Queue.start_link()
    [state: {0, queue, 10}, queue: queue]
  end

  test "handle zero demand with zero backlog", %{state: state} do
    {:noreply, [], _} = Producer.handle_demand(0, state)
  end

  test "handle demand", %{state: {demand, _, check_interval}} do
    assert {:ok, queue} = Queue.start_link()
    assert :ok = Queue.push_async(queue, '123')

    state = {demand, queue, check_interval}
    {:noreply, '123', _} = Producer.handle_demand(3, state)
  end

  test "handle info with no backlog", %{state: state} do
    assert {:noreply, [], _} = Producer.handle_info(:dispatch_events, state)
  end

  test "handle info with backlog", %{state: state} do
    assert {:ok, queue} = Queue.start_link()
    assert :ok = Queue.push_async(queue, '123')

    state = {3, queue, elem(state, 2)}
    assert {:noreply, '123', _} = Producer.handle_info(:dispatch_events, state)
  end

  test "start_link" do
    assert {:ok, q} = GenServer.start_link(Queue, [])
    assert {:ok, p} = Producer.start_link(queue: q)
    assert is_pid(p)
  end

  test "no proc blocks" do
    state = {0, FakeProc, 10}

    spawn_link(fn ->
      Process.sleep(90)
      Queue.start_link(name: FakeProc)
      Queue.push(FakeProc, 'test')
    end)

    {:noreply, 'test', _} = Producer.handle_demand(10, state)
  end

  test "killed blocks" do
    state = {0, KillProc, 10}

    spawn(fn ->
      assert {:ok, pid} = Queue.start_link(name: KillProc)
      assert true = Process.exit(pid, :kill)
    end)

    spawn(fn ->
      Process.sleep(50)

      [name: KillProc]
      |> Queue.start_link()
      |> elem(1)
      |> Queue.push('test')
    end)

    assert {:noreply, 'test', _} = Producer.handle_demand(10, state)
  end

  test "no sleep" do
    assert {:ok, q} = GenServer.start_link(Queue, [])
    assert {:ok, _} = Producer.start_link(queue: q, check_interval: nil)
  end
end
