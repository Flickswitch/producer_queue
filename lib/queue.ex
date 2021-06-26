defmodule ProducerQueue.Queue do
  @moduledoc """
  ## Start under a supervisor or application:

      alais ProducerQueue.Queue

      children = [
        {Queue, name: SomeSimpleMod},
        {Queue, name: SomeAdvancedMod, priority: SomeAdvancedMod.priority()},
        # queue consumers here
      ]

  See: pop/2, push/2, push_async/2, and start_link/1 for details

  ## Priority Queues

      iex> alias ProducerQueue.Queue
      ...> {:ok, q} = Queue.start_link(priority: [:high, :medium, :low])
      ...> :ok = Queue.push(q, medium: [4, 5, 6])
      ...> :ok = Queue.push_async(q, low: [7, 8, 9])
      ...> :ok = Queue.push(q, high: [1, 2])
      ...> :ok = Queue.push_async(q, high: 3)
      ...> Queue.pop(q, 10)
      [1, 2, 3, 4, 5, 6, 7, 8, 9]
  """

  use GenServer

  @wait 10_000

  @doc """
  ## Example: Using a custom queue server implementation:

      iex> alias ProducerQueue.Queue
      ...> {:ok, _pid} = Queue.start_link(module: MyCustomQueueImplementation)
  """
  def start_link(opts \\ []) do
    server = Keyword.get(opts, :server, ProducerQueue.PriorityKeyServer)
    GenServer.start_link(server, opts, opts)
  end

  @doc ~s"""
  Pop a number of items of the front of a queue (timeout: #{@wait})

  ## Example

      iex> alias ProducerQueue.Queue
      ...> {:ok, q} = Queue.start_link([]); :ok = Queue.push_async(q, [:a, :b])
      ...> Queue.pop(q, 1)
      [:a]

  See: `Queue` for priority queue details
  """
  @spec pop(queue :: pid | term, count :: non_neg_integer()) :: list()
  def pop(queue, count \\ 1), do: pop(:call, queue, count)

  @doc ~s"""
  Push a list of items on to the back of a queue (timeout: #{@wait})

  ## Example

      iex> alias ProducerQueue.Queue
      ...> {:ok, q} = Queue.start_link([])
      ...> :ok = Queue.push(q, :a); :ok = Queue.push(q, [:b, :c])
      ...> [:a, :b, :c] = Queue.pop(q, 3)
      [:a, :b, :c]

  See: `Queue` for priority queue details
  """
  @spec push(queue :: pid | term, item_or_list :: list() | term()) :: :ok
  def push(queue, list), do: push(:call, queue, list)

  @doc ~s"""
  Push a list of items on to the back of a queue (without blocking)

  ## Example

      iex> alias ProducerQueue.Queue
      ...> {:ok, q} = Queue.start_link([])
      ...> :ok = Queue.push_async(q, :a); :ok = Queue.push_async(q, [:b, :c])
      ...> [:a, :b, :c] = Queue.pop(q, 3)
      [:a, :b, :c]

  See: `Queue` for priority queue details
  """
  @spec push_async(queue :: pid | term, item_or_list :: list() | term()) :: :ok
  def push_async(queue, list), do: push(:cast, queue, list)

  def init(noop), do: {:ok, noop}

  defp pop(_, _, count) when not is_integer(count) or count < 1, do: []
  defp pop(:call, term, count), do: GenServer.call(term, {:pop, count}, @wait)
  defp push(_, _, []), do: :ok
  defp push(_, _, [{_, []}]), do: :ok
  defp push(s, p, [{key, i}]) when not is_list(i), do: push(s, p, [{key, [i]}])
  defp push(:cast, pid, [{_, _} = p]), do: GenServer.cast(pid, {:push, p})
  defp push(:call, pid, [{_, _} = p]), do: GenServer.call(pid, {:push, p}, @wait)
  defp push(sync, term, default), do: push(sync, term, _: default)
end
