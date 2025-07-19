defmodule Shared.Release do
  @moduledoc """
  Release tasks for production deployment.
  
  This module contains tasks that need to be run in production,
  such as database migrations.
  """

  @app :shared

  def migrate do
    IO.puts("Starting database migrations...")
    
    # Load the application
    load_app()
    
    # Run migrations for each repo
    for repo <- repos() do
      app = Keyword.get(repo.config(), :otp_app)
      IO.puts("Running migrations for #{inspect(repo)}...")
      
      # Get migration path
      migrations_path = priv_path_for(repo, app, "migrations")
      
      # Run migrations
      case Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, migrations_path, :up, all: true)) do
        {:ok, _, _} ->
          IO.puts("Migrations completed for #{inspect(repo)}")
        {:error, error} ->
          IO.puts("Migration failed for #{inspect(repo)}: #{inspect(error)}")
          raise "Migration failed"
      end
    end
    
    IO.puts("All migrations completed successfully!")
  end

  def rollback(repo, version) do
    load_app()
    app = Keyword.get(repo.config(), :otp_app)
    migrations_path = priv_path_for(repo, app, "migrations")
    
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, migrations_path, :down, to: version))
  end

  def migrate_query do
    IO.puts("Starting Query Service migrations...")
    
    # Load only necessary applications
    Application.load(:query_service)
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:postgrex)
    Application.ensure_all_started(:ecto_sql)
    
    # Get the migrations path for query service
    migrations_path = case :code.priv_dir(:query_service) do
      {:error, :bad_name} ->
        app_dir = Application.app_dir(:query_service)
        Path.join([app_dir, "priv", "repo", "migrations"])
      priv_dir ->
        Path.join([priv_dir, "repo", "migrations"])
    end
    
    IO.puts("Using migrations path: #{migrations_path}")
    
    # List all migration files
    if File.exists?(migrations_path) do
      files = File.ls!(migrations_path)
      IO.puts("Found migration files: #{inspect(files)}")
    else
      IO.puts("Migration path does not exist!")
    end
    
    # Run migrations
    case Ecto.Migrator.with_repo(QueryService.Repo, &Ecto.Migrator.run(&1, migrations_path, :up, all: true)) do
      {:ok, _, _} ->
        IO.puts("Query Service migrations completed successfully!")
      {:error, error} ->
        IO.puts("Query Service migration failed: #{inspect(error)}")
        raise "Migration failed"
    end
  end

  defp repos do
    [
      Shared.Infrastructure.EventStore.Repo,
      CommandService.Repo,
      QueryService.Repo
    ]
  end

  defp load_app do
    Application.load(@app)
    
    # Ensure all apps are loaded
    Application.load(:command_service)
    Application.load(:query_service)
    
    # Start dependencies
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:postgrex)
    Application.ensure_all_started(:ecto_sql)
  end
  
  defp priv_path_for(_repo, app, filename) do
    # Get the priv directory for the app
    case :code.priv_dir(app) do
      {:error, :bad_name} ->
        # If not in release, use relative path
        app_dir = Application.app_dir(app)
        Path.join([app_dir, "priv", "repo", filename])
      priv_dir ->
        # In release, use the priv directory
        Path.join([priv_dir, "repo", filename])
    end
  end
end