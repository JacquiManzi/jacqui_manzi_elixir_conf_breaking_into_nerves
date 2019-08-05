defmodule HelloNerves.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    opts = [strategy: :one_for_one, name: HelloNerves.Supervisor]
    port = Application.get_env(:hello_nerves, :port)
    camera = Application.get_env(:picam, :camera, Picam.Camera)

    children =
      [
        worker(HelloNerves.Motion.Worker, []),
        worker(camera, []),
        {Plug.Cowboy, scheme: :http, plug: HelloNerves.Router, options: [port: port]}
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  def children(:host) do
    []
  end

  def children(_target) do
    []
  end

  def target() do
    Application.get_env(:hello_nerves, :target)
  end
end
