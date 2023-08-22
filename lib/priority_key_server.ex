defmodule ProducerQueue.PriorityKeyServer do
  @moduledoc """
  ## Implementation details:

      iex> alias ProducerQueue.PriorityKeyServer
      ...> priority_keys = [:h, :l, :empty]
      ...> high = {3, :queue.from_list([1, 2, 3])}
      ...> low = {4, :queue.from_list(~w(d e f g)a)}
      ...> empty = {0, {[], []}}
      ...> state = {priority_keys, %{h: high, l: low, empty: empty}}
      ...> {_, [1], state} = PriorityKeyServer.handle_call({:pop, 1}, :_, state)
      ...> {_, [2, 3], state} = PriorityKeyServer.handle_call({:pop, 2}, :_, state)
      ...> {_, _, state} = PriorityKeyServer.handle_call({:push, {:h, [4]}}, :_, state)
      ...> {_, [4], _state} = PriorityKeyServer.handle_call({:pop, 1}, :_, state)

      iex> alias ProducerQueue.PriorityKeyServer
      ...> priority_keys = [:h, :l, :empty]
      ...> high = {3, :queue.from_list([1, 2, 3])}
      ...> low = {4, :queue.from_list(~w(d e f g)a)}
      ...> empty = {0, {[], []}}
      ...> state = {priority_keys, %{h: high, l: low, empty: empty}}
      ...> {_, [], state} = PriorityKeyServer.handle_call({:pop, 0}, :_, state)
      ...> {_, [1, 2, 3, :d, :e, :f, :g], _} = PriorityKeyServer.handle_call({:pop, 10}, :_, state)

      iex> alias ProducerQueue.PriorityKeyServer
      ...> priority_keys = [:h, :l]
      ...> empty = {0, {[], []}}
      ...> state = {priority_keys, %{h: empty, l: empty}}
      ...> {:noreply, state} = PriorityKeyServer.handle_cast({:push, {:_, [:a]}}, state)
      ...> {_, [:a], _} = PriorityKeyServer.handle_call({:pop, 1}, :_, state)

      iex> alias ProducerQueue.PriorityKeyServer
      ...> {_, {[:a, :b, :c], _}} = PriorityKeyServer.init(priority: [:a, :b, :c])

  """

  use GenServer
  @q {0, {[], []}}

  def init(opts), do: init(:priority, Keyword.get(opts, :priority, [:default]))
  def init(:priority, prio), do: {:ok, {prio, Enum.into(prio, %{}, &{&1, @q})}}

  def handle_call(:size_map, _, {prio, queues} = state) do
    for key <- prio, into: %{} do
      {key, queues |> Map.get(key) |> elem(0)}
    end
    |> Map.put(:_, prio)
    |> then(&{:reply, &1, state})
  end

  def handle_call({:pop, count}, _, state), do: out(count, state)
  def handle_call({:push, list}, _, state), do: {:reply, :ok, qin(list, state)}
  def handle_cast({:push, list}, state), do: {:noreply, qin(list, state)}

  defp out(i, state), do: out(i, state, _acc = [], _prio_list = elem(state, 0))
  defp out(0, state, acc, _), do: {:reply, Enum.reverse(acc), state}
  defp out(_, state, acc, []), do: out(0, state, acc, _empty_prio_list = [])
  defp out(i, {_, m} = s, acc, [hd | tl]), do: out(i, s, acc, [hd | tl], m[hd])
  defp out(i, {p, m}, l, [k | t], @q), do: out(i, {p, Map.put(m, k, @q)}, l, t)
  defp out(0, {p, m}, l, [k | _], q), do: out(0, {p, Map.put(m, k, q)}, l, [])
  defp out(i, s, l, p, {c, q}), do: out(i - 1, s, l, p, {c, q}, :queue.out(q))
  defp out(i, s, l, p, {c, _}, {{_, v}, q}), do: out(i, s, [v | l], p, {c - 1, q})

  defp qin({:_, list}, {prio, map}), do: qin({hd(prio), list}, {prio, map})
  defp qin({k, l}, {p, %{} = m}), do: qin(p, m, k, Enum.reduce(l, m[k], &qin/2))
  defp qin(item, {size, queue} = _acc), do: {size + 1, :queue.in(item, queue)}
  defp qin(p, m, k, acc), do: {p, Map.put(m, k, acc)}
end
