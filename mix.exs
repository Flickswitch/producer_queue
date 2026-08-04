defmodule ProducerQueue.MixProject do
  use Mix.Project

  def project do
    [
      app: :producer_queue,
      version: "5.0.3",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      description: "Elixir library for basic prioritized queues with a producer for Broadway",
      package: package()
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Flickswitch/producer_queue"},
      files: ~w(lib mix.exs README.md LICENSE)
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application, do: [extra_applications: []]

  defp deps do
    [
      {:broadway, "~> 1.0", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:gen_stage, "~> 1.1"}
    ]
  end
end
