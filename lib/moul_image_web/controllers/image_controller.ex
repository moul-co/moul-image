defmodule MoulImageWeb.ImageController do
  use MoulImageWeb, :controller

  @request Req.new(base_url: Application.compile_env(:moul_image, [:image_base_url]))

  def thumbnail(conn, params) do
    etag =
      :sha256
      |> :crypto.hash(conn.query_string)
      |> Base.encode16(case: :lower)

    if_none_match =
      conn
      |> get_req_header("if-none-match")
      |> List.first()

    if if_none_match == etag do
      send_resp(conn, 304, "Not Modified")
    else
      size = params |> Map.get("size") |> get_size()

      with {:ok, %Req.Response{} = res} <- Req.get(@request, url: Map.get(params, "path")),
           true <- Map.get(res.headers, "content-type") == ["image/jpeg"],
           {:ok, image} <- Image.open(res.body),
           {:ok, thumb} <- Image.thumbnail(image, size) do
        conn =
          conn
          |> put_resp_header("content-type", "image/jpeg")
          |> put_resp_header("etag", etag)
          |> put_resp_header("cache-control", "public, max-age=31536000")
          |> send_chunked(200)

        Image.write!(thumb, conn, suffix: ".jpg", jpg: [quality: 98, progressive: true])

        conn
      else
        _ -> send_resp(conn, 400, "Bad Request")
      end
    end
  end

  def thumbhash(conn, params) do
    etag =
      :sha256
      |> :crypto.hash(conn.query_string)
      |> Base.encode16(case: :lower)

    if_none_match =
      conn
      |> get_req_header("if-none-match")
      |> List.first()

    if if_none_match == etag do
      send_resp(conn, 304, "Not Modified")
    else
      encode = Map.get(params, "encode")
      decode = Map.get(params, "decode")

      with {:ok, %Req.Response{} = res} <- Req.get(@request, url: Map.get(params, "path")),
           true <- Map.get(res.headers, "content-type") == ["image/jpeg"],
           {:ok, img} <- Image.open(res.body),
           {:ok, thumb} <- Image.thumbnail(img, 100),
           {:ok, _} <- Image.write(thumb, "/tmp/#{etag}.jpeg") do
        process_thumbhash(conn, encode, decode, etag)
      else
        _ -> send_resp(conn, 400, "Bad Request")
      end
    end
  end

  defp process_thumbhash(conn, nil, nil, _etag), do: send_resp(conn, 400, "Bad Request")

  defp process_thumbhash(conn, _encode, decode, etag) when is_nil(decode) do
    with {:ok, hash} <- MoulImage.encode_thumbhash("/tmp/#{etag}.jpeg") do
      conn
      |> put_resp_header("etag", etag)
      |> put_resp_header("cache-control", "public, max-age=31536000")
      |> send_resp(200, hash)
    else
      _ -> send_resp(conn, 400, "Bad Request")
    end
  end

  defp process_thumbhash(conn, _encode, _decode, etag) do
    boost = Map.get(conn.query_params, "boost", 1.5)

    with {:ok, hash} <- MoulImage.encode_thumbhash("/tmp/#{etag}.jpeg"),
         {:ok, img} <- MoulImage.decode_thumbhash(hash, boost) do
      conn =
        conn
        |> put_resp_header("content-type", "image/jpeg")
        |> put_resp_header("etag", etag)
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
  end

  defp get_size("xl"), do: 4096
  defp get_size("lg"), do: 2048
  defp get_size("md"), do: 1024
  defp get_size(_), do: 32
end
