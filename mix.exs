defmodule ProducerQueue.MixProject do
  use Mix.Project

  def project do
    [
      app: :producer_queue,
      version: "5.0.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
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
      {:broadway, "~> 0.6.2", only: :dev},
      {:credo, "~> 1.5.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.14.0", only: :test},
      {:gen_stage, "~> 1.1"}
    ]
  end
end
