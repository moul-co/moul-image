defmodule MoulImageWeb.ImageController do
  use MoulImageWeb, :controller

  @request Req.new(base_url: Application.compile_env(:moul_image, [:image_base_url]))

  def thumbnail(conn, params) do
    hash =
      :sha256
      |> :crypto.hash(conn.query_string)
      |> Base.encode16(case: :lower)

    if get_req_header(conn, "if-none-match")
       |> List.first() ==
         hash do
      send_resp(conn, 304, "Not Modified")
    else
      size = params |> Map.get("size") |> get_size()

      req = Req.get!(@request, url: Map.get(params, "path"))

      conn =
        conn
        |> put_resp_header("content-type", "image/jpeg")
        |> put_resp_header("etag", hash)
        |> put_resp_header("cache-control", "public, max-age=31536000")
        |> send_chunked(200)

      Image.open!(req.body)
      |> Image.thumbnail!(size)
      |> Image.write!(conn, suffix: ".jpg", jpg: [quality: 98, progressive: true])

      conn
    end
  end

  def thumbhash(conn, params) do
    hash_path =
      :sha256
      |> :crypto.hash(conn.query_string)
      |> Base.encode16(case: :lower)

    if get_req_header(conn, "if-none-match")
       |> List.first() ==
         hash_path do
      send_resp(conn, 304, "Not Modified")
    else
      encode = Map.get(params, "encode")
      decode = Map.get(params, "decode")
      boost = Map.get(params, "boost", 1.5)

      req =
        Req.get!(@request, url: Map.get(params, "path"))

      Image.open!(req.body)
      |> Image.thumbnail!(100)
      |> Image.write!("/tmp/#{hash_path}.jpeg")

      cond do
        is_nil(decode) and not is_nil(encode) ->
          with {:ok, hash} <- MoulImage.encode_thumbhash("/tmp/#{hash_path}.jpeg") do
            conn
            |> put_resp_header("etag", hash_path)
            |> put_resp_header("cache-control", "public, max-age=31536000")
            |> send_resp(200, hash)
          else
            _ -> send_resp(conn, 400, "Bad Request")
          end

        not is_nil(decode) and not is_nil(encode) ->
          with {:ok, hash} <- MoulImage.encode_thumbhash("/tmp/#{hash_path}.jpeg"),
               {:ok, img} <- MoulImage.decode_thumbhash(hash, boost) do
            conn =
              conn
              |> put_resp_header("content-type", "image/png")
              |> put_resp_header("etag", hash_path)
              |> put_resp_header("cache-control", "public, max-age=31536000")
              |> send_chunked(200)

            img
            |> String.trim_leading("data:image/png;base64,")
            |> Base.decode64!()
            |> Image.open!()
            |> Image.write!(conn, suffix: ".jpg", jpg: [quality: 98, progressive: true])

            conn
          else
            _ -> send_resp(conn, 400, "Bad Request")
          end

        true ->
          send_resp(conn, 400, "Bad Request")
      end
    end
  end

  defp get_size("xl"), do: 4096
  defp get_size("lg"), do: 2048
  defp get_size("md"), do: 1024
  defp get_size(_), do: 32
end
