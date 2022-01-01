defmodule OGNCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :ogn_core,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {OGNCore.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cbor, "~> 1.0"},
      {:toml, "~> 0.6.2"},
      {:logger_file_backend, "~> 0.0.12"},
      {:tortoise, "~> 0.10.0"}
    ]
  end
end
