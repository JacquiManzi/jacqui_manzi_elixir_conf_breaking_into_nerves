defmodule HelloNerves.Streamer do
  @moduledoc """
  Plug for streaming an image
  """
  import Plug.Conn
  require Logger

  @behaviour Plug
  @boundary "w58EW1cEpjzydSCq"

  def init(opts), do: opts

  def call(conn, _opts) do
    pid = Process.whereis(MotionDetectionWorker)
    conn
    |> put_resp_header("Age", "0")
    |> put_resp_header("Cache-Control", "no-cache, private")
    |> put_resp_header("Pragma", "no-cache")
    |> put_resp_header("Content-Type", "multipart/x-mixed-replace; boundary=#{@boundary}")
    |> send_chunked(200)
    |> send_pictures(pid)
  end

  defp send_pictures(conn, pid) do
    jpg = get_picture(conn, pid)
    [{:moving, is_moving}, count] = :sys.get_state(pid)
    if is_moving do
      send_picture(conn, jpg)
    end
    send_pictures(conn, pid)
  end

  defp get_picture(conn, pid) do
    Picam.set_size(900, 0)
    jpg = Picam.next_frame()
    size = byte_size(jpg)

    GenServer.cast(pid, {:detect_motion, jpg})
    jpg
  end

  defp send_picture(conn, jpg) do
    size = byte_size(jpg)
    header = "------#{@boundary}\r\nContent-Type: image/jpeg\r\nContent-length: #{size}\r\n\r\n"
    footer = "\r\n"

    with {:ok, conn} <- chunk(conn, header),
         {:ok, conn} <- chunk(conn, jpg),
         {:ok, conn} <- chunk(conn, footer),
         do: conn
  end
end
