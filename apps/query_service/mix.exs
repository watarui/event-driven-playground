defmodule QueryService.MixProject do
  use Mix.Project

  def project do
    [
      app: :query_service,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :shared],
      mod: {QueryService.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:shared, in_umbrella: true},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.17"},
      {:jason, "~> 1.4"},
      {:cowlib, "~> 2.13", override: true},
      {:plug, "~> 1.15"},
      {:plug_cowboy, "~> 2.6"}
    ]
  end
end
