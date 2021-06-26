defmodule ProducerQueue.Example.Broadway do
  @moduledoc """
  Example of `ProducerQueue` with `Broadway`

  Usage

      ...> ProducerQueue.Example.Broadway.start_deps()
      ...> ProducerQueue.Example.Broadway.start_link(name: ExampleModule, queue: ExampleQueue)
      ...> spawn(ProducerQueue.Example.Broadway, :queue, ['abcdefghjiklmnopqrstuvwxyz'])
      ...> spawn(ProducerQueue.Example.Broadway, :queue, ['ABCDEFGHJIKLMNOPQRSTUVWXYZ'])

  """

  use Broadway

  def start_deps, do: ProducerQueue.Queue.start_link(name: ExampleQueue)

  def start_link(opts) do
    Broadway.start_link(__MODULE__,
      name: opts[:name] || __MODULE__,
      producer: [
        module: {ProducerQueue.Producer, queue: opts[:queue]},
        concurrency: 1,
        transformer: {__MODULE__, :message_from_queue, []}
      ],
      processors: [default: [concurrency: 4]],
      batchers: [default: [concurrency: 4, batch_size: 10, batch_timeout: 250]]
    )
  end

  def queue(list), do: ProducerQueue.Queue.push(ExampleQueue, list)

  def message_from_queue(data, _opts) do
    %Broadway.Message{acknowledger: {__MODULE__, :ack_id, :ack_data}, data: data}
  end

  def handle_message(_producer, message, _context), do: message

  def handle_batch(_batcher, messages, _batch_info, _context) do
    IO.puts("messages (#{length(messages)}) #{inspect Enum.map(messages, & &1.data)}")
    messages
  end

  def ack(:ack_id, messages, _), do: :ok
end
