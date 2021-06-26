defmodule ProducerQueue.ProducerTest do
  use ExUnit.Case

  alias ProducerQueue.Producer
  alias ProducerQueue.Queue

  setup do
    {:ok, queue} = Queue.start_link()
    [state: {:state, 0, queue, 10}, queue: queue]
  end

  test "init sets up check", %{state: state} do
    {_, _} = Producer.init(state)
    assert_receive(:c)
  end

  test "handle zero demand with zero backlog", %{state: state} do
    {:noreply, [], _} = Producer.handle_demand(0, state)
  end

  test "handle demand", %{state: state} do
    assert {:ok, queue} = Queue.start_link()
    assert :ok = Queue.push_async(queue, '123')
    state = {:state, elem(state, 1), queue, elem(state, 3)}
    {:noreply, '123', _} = Producer.handle_demand(3, state)
  end

  test "handle info with no backlog", %{state: state} do
    assert {:noreply, [], _} = Producer.handle_info(:c, state)
  end

  test "handle info with backlog", %{state: state} do
    assert {:ok, queue} = Queue.start_link()
    assert :ok = Queue.push_async(queue, '123')
    state = {:state, 3, queue, elem(state, 3)}
    assert {:noreply, '123', _} = Producer.handle_info(:c, state)
  end

  test "start_link" do
    assert {:ok, q} = GenServer.start_link(Queue, [])
    assert {:ok, p} = Producer.start_link(queue: q)
    assert is_pid(p)
  end

  test "no proc blocks" do
    state = {:state, 0, FakeProc, 10}

    spawn_link(fn ->
      Process.sleep(90)
      Queue.start_link(name: FakeProc)
      Queue.push(FakeProc, 'test')
    end)

    {:noreply, 'test', _} = Producer.handle_demand(10, state)
  end

  test "killed blocks" do
    state = {:state, 0, KillProc, 10}

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
end
