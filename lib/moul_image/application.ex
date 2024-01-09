defmodule MoulImage.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MoulImageWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:moul_image, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MoulImage.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: MoulImage.Finch},
      # Start a worker by calling: MoulImage.Worker.start_link(arg)
      # {MoulImage.Worker, arg},
      # Start to serve requests, typically the last entry
      MoulImageWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MoulImage.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MoulImageWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
