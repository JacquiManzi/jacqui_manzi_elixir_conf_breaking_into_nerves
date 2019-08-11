defmodule HelloNerves.Motion.MotionDetection do
  import ExImageInfo
  require Logger

  def detect_motion(image) do
    pixel_list = get_pixel_list(image)
  end

  defp get_pixel_list(image_binary) do
    image_binary
    |> :binary.bin_to_list()
  end
end
