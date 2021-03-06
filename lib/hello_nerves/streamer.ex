defmodule HelloNerves.Streamer do
  @moduledoc """
  Plug for streaming an image
  """
  import Plug.Conn
  require Logger

  @behaviour Plug
  @boundary "w51JacquiManziElixirConfcEpydSCq"

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("Age", "0")
    |> put_resp_header("Cache-Control", "no-cache, private")
    |> put_resp_header("Pragma", "no-cache")
    |> put_resp_header("Content-Type", "multipart/x-mixed-replace; boundary=#{@boundary}")
    |> send_chunked(200)
    |> send_pictures()
  end

  defp send_pictures(conn) do
    send_picture(conn)
    send_pictures(conn)
  end

  defp send_picture(conn) do
    if Process.whereis(Picam.Camera) != nil do
      Picam.set_size(900, 0)

      jpg = Picam.next_frame()
      size = byte_size(jpg)
      header = "------#{@boundary}\r\nContent-Type: image/jpeg\r\nContent-length: #{size}\r\n\r\n"
      footer = "\r\n"

      pid = Process.whereis(MotionDetectionWorker)
      GenServer.cast(pid, {:detect_motion, jpg})

      with {:ok, conn} <- chunk(conn, header),
           {:ok, conn} <- chunk(conn, jpg),
           {:ok, conn} <- chunk(conn, footer),
           do: conn
    else
      conn
    end
  end
end
