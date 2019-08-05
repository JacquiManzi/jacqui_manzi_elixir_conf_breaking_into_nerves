defmodule HelloNerves.Motion.MotionDetection do
  import ExImageInfo
  alias Porcelain.Result

  def detect_motion(image) do
    %Result{out: decompressed_image, status: status} =
      Porcelain.exec("djpeg", ["-bmp", "#{image}"], in: "src/libjpeg/.libs/djpeg")

    # @TODO: Remove this dependancy and just use the hex values for the width and height
    {_format, _width, height, _encode} = ExImageInfo.info(decompressed_image)
    pixel_list = get_pixel_list(decompressed_image)
  end

  defp get_pixel_list(image_binary) do
    image_binary
    |> :binary.bin_to_list()
  end
end
