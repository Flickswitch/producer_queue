defmodule ProducerQueue.Producer do
  @moduledoc """
  A simple implementation of a GenStage producer
  """

  use GenStage

  @doc """
  Start a `ProducerQueue.Producer` linked to a `ProducerQueue.Queue`
  """
  def start_link(opts \\ []), do: GenStage.start_link(__MODULE__, opts)

  def init(opts) when is_list(opts) do
    init({:state, 0, Keyword.get(opts, :queue), Keyword.get(opts, :check, 10)})
  end

  def init(state), do: {:producer, state} |> check()
  def handle_demand(0, {_, 0, _, _} = state), do: check({:noreply, [], state})
  def handle_demand(new, {_, old, _, _} = state), do: demand(state, new + old)
  def handle_info(:c, {_, 0, _, _} = state), do: check({:noreply, [], state})
  def handle_info(:c, {_, old, _, _} = state), do: demand(state, old)

  defp check({:producer, state}), do: {:producer, check(state)}
  defp check({:noreply, push, state}), do: {:noreply, push, check(state)}
  defp check({_, _, _, nil} = state), do: send(self(), :c) && state
  defp check(state), do: Process.send_after(self(), :c, elem(state, 3)) && state

  defp demand({:state, _, queue, _} = state, total) do
    state
    |> demand(total, queue, 100, 3_000)
    |> then(&{:noreply, &1, {:state, total - length(&1), queue, 0}})
    |> check()
  end

  defp demand(_, _total, _queue, _, limit) when limit < 0, do: []

  defp demand(state, total, queue, sleep, limit) do
    apply(ProducerQueue.Queue, :pop, [queue, total])
  catch
    :exit, _ ->
      Process.sleep(sleep)
      demand(state, total, queue, sleep, limit - sleep)
  end
end
