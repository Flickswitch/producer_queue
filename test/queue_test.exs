defmodule ProducerQueue.QueueTest do
  use ExUnit.Case

  doctest ProducerQueue.Queue
  doctest ProducerQueue.PriorityKeyServer

  alias ProducerQueue.Queue

  describe "simple" do
    setup do
      [pid: elem({:ok, _pid} = Queue.start_link([]), 1)]
    end

    test "pop when nothing was added", %{pid: pid} do
      assert [] == Queue.pop(pid)
    end

    test "push onto the queue", %{pid: pid} do
      assert :ok = Queue.push(pid, :s)
    end

    test "push a list of items onto the queue", %{pid: pid} do
      assert :ok = Queue.push(pid, [:o, :c, :s])
    end

    test "push an item onto the queue async", %{pid: pid} do
      assert :ok = Queue.push_async(pid, :o)
    end

    test "push a list of items onto the queue async", %{pid: pid} do
      assert :ok = Queue.push_async(pid, [:o, :c, :s])
    end

    test "pop an item off the queue", %{pid: pid} do
      Queue.push(pid, :o)
      assert [:o] = Queue.pop(pid)
    end

    test "pop more items off the queue", %{pid: pid} do
      Queue.push_async(pid, [:o, :c, :s])
      assert [:o, :c] = Queue.pop(pid, 2)
    end
  end

  describe "priority" do
    setup do
      Queue.start_link(name: TestQueue, priority: [:high, :medium, :low]) && :ok
    end

    test "basic push" do
      assert :ok = Queue.push(TestQueue, :a)
    end

    test "basic list push" do
      assert :ok = Queue.push(TestQueue, [:a, :b, :c])
    end

    test "basic async push" do
      assert :ok = Queue.push_async(TestQueue, :a)
    end

    test "basic async list push" do
      assert :ok = Queue.push_async(TestQueue, [:a, :b, :c])
    end

    test "pop/1 empty list" do
      assert [] == Queue.pop(TestQueue)
    end

    test "pop/2 empty list" do
      assert [] == Queue.pop(TestQueue, 2)
    end

    test "pop/1 and pop/2 fetches items" do
      assert [] == Queue.pop(TestQueue, 1)
      assert [] == Queue.pop(TestQueue, 2)
      assert :ok = Queue.push(TestQueue, :a)
      assert :ok = Queue.push(TestQueue, [:b, :c])
      assert [:a] = Queue.pop(TestQueue, 1)
      assert [:b, :c] = Queue.pop(TestQueue, 2)
    end

    test "items are pushed and pulled by priority queue" do
      assert :ok = Queue.push(TestQueue, low: [:low1, :low2, :low3])
      assert :ok = Queue.push_async(TestQueue, high: [:high_first, :high_second])
      assert :ok = Queue.push(TestQueue, medium: [:medium_A, :medium_B])

      assert [:high_first, :high_second, :medium_A] = Queue.pop(TestQueue, 3)
      assert [:medium_B, :low1] = Queue.pop(TestQueue, 2)
      assert [:low2] = Queue.pop(TestQueue)
      assert [:low3] = Queue.pop(TestQueue, 2)
      assert [] = Queue.pop(TestQueue)
      assert [] = Queue.pop(TestQueue, 2)
    end
  end

  describe "edge cases" do
    setup do
      [queue: elem({:ok, _pid} = Queue.start_link(), 1)]
    end

    test "pushing nothing onto the queue does nothing", %{queue: q} do
      assert :ok = Queue.push(q, [])
      assert :ok = Queue.push(q, _: [])
      assert [] = Queue.pop(q)
    end

    test "popping an empty queue does nothing", %{queue: q} do
      assert [] = Queue.pop(q)
      assert [] = Queue.pop(q, 1)
      assert [] = Queue.pop(q, 0)
    end
  end
end
