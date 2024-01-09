defmodule MoulImage do
  @moduledoc """
  MoulImage keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  @env Application.compile_env(:moul_image, [:env])

  def encode_thumbhash(path) when is_nil(path), do: {:error, nil}

  def encode_thumbhash(path) do
    args = ["encode", "--thumbhash", "true", "--in", "#{path}"]

    case System.cmd(get_bin_path(), args) do
      {result, 0} ->
        {:ok, result}

      {_, exit_status} ->
        {:error, exit_status}
    end
  end

  def decode_thumbhash(hash, 1.5) when is_nil(hash), do: {:error, nil}

  def decode_thumbhash(hash, boost) do
    args = ["decode", "--thumbhash", "#{hash}", "--boost", "#{boost}"]

    case System.cmd(get_bin_path(), args) do
      {result, 0} ->
        {:ok, result}

      {_, exit_status} ->
        {:error, exit_status}
    end
  end

  defp get_bin_path do
    if @env == :prod do
      Path.join(:code.priv_dir(:moul_image), "moul-cli/moul")
    else
      "moul"
    end
  end
end
