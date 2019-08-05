defmodule HelloNerves.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  require Logger;

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    opts = [strategy: :one_for_one, name: HelloNerves.Supervisor]
    port = Application.get_env(:hello_nerves, :port)
    camera = Application.get_env(:picam, :camera, Picam.Camera)
    children =
      [
        # Children for all targets
        # Starts a worker by calling: HelloNerves.Worker.start_link(arg)
        # {HelloNerves.Worker, arg},
        worker(camera, []),
        {Plug.Cowboy, scheme: :http, plug: HelloNerves.Router, options: [port: 4001]},
      ] ++ children(target())
    Logger.info("starting the children")

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: HelloNerves.Worker.start_link(arg)
      # {HelloNerves.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: HelloNerves.Worker.start_link(arg)
      # {HelloNerves.Worker, arg},
    ]
  end

  def target() do
    Application.get_env(:hello_nerves, :target)
  end
end
