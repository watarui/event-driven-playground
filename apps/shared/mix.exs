defmodule Shared.MixProject do
  use Mix.Project

  def project do
    [
      app: :shared,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Event Store Repo を追加
      ecto_repos: [Shared.Infrastructure.EventStore.Repo]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Shared.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.15"},
      {:ecto, "~> 3.11"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.17"},
      {:jason, "~> 1.4"},
      {:decimal, "~> 2.1"},
      {:elixir_uuid, "~> 1.2"},
      {:typed_struct, "~> 0.3.0"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_exporter, "~> 1.6"},
      {:phoenix_pubsub, "~> 2.1"},
      {:finch, "~> 0.18"},
      {:google_api_pub_sub, "~> 0.36"},
      {:google_api_firestore, "~> 0.26"},
      {:goth, "~> 1.4"}
    ]
  end
end
