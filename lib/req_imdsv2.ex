defmodule ReqIMDSv2 do
  @moduledoc """
  Provides a way to automatically authenticate Req requests with the Instance Metadata Service on
  an Amazon AWS EC2 instance.

  It does this by making a request to IMDSv2 to get a token before the main request, then attaches that token
  to the request.

  The EC2 docs specify that it's perfectly fine to request a new token for each request, but if you're making a
  lot in a row, it's possible to extract the token from the response and reuse it for subsequent requests. See
  `get_metadata_token/1` for more info.

  ## Examples

      iex> Req.new(url: "http://169.254.169.254/latest/meta-data/instance-id")
      ...> |> ReqIMDSv2.attach()
      ...> |> Req.get()
      {:ok, %Req.Response{body: "i-1234567890abcdef0", ...}

  See `attach/2` for options and more examples.

  """

  require Logger

  alias Req.Request
  alias Req.Response

  @doc """
  Attaches the IMDSv2 authentication steps to the request.

  ## Options

  * `:metadata_token` - A token to use for authentication. If not provided, a new token will be fetched. See
      `get_metadata_token/1` for more info on extracting a token from a response.
  * `:metadata_token_ttl_seconds` - The TTL for the token. Defaults to the max allowed of 21600 (6 hours).
  * `:fallback_to_imdsv1` - If true, will fall back to IMDSv1 if IMDSv2 is not available, otherwise the request will
      return an error. Defaults to false.

  ## Examples

        iex> req = Req.new(url: "http://169.254.169.254/latest/meta-data/instance-id")
        iex> req = ReqIMDSv2.attach(req)
        iex> {:ok, resp} = Req.get(req)
        iex> resp.body
        "i-1234567890abcdef0"

    You can then extract the token from the response and reuse it for subsequent requests:

        iex> token = ReqIMDSv2.get_metadata_token(resp)
        iex> req = Req.new(url: "http://169.254.169.254/latest/meta-data/hostname")
        ...> |> ReqIMDSv2.attach(metadata_token: token)
        iex> Req.get!(req).body
        "i-1234567890abcdef0"

  """
  @spec attach(Request.t(), Keyword.t()) :: Request.t()
  def attach(%Request{} = request, options \\ []) do
    request
    |> Request.register_options([
      :metadata_token,
      :metadata_token_ttl_seconds,
      :fallback_to_imdsv1
    ])
    |> Request.merge_options(options)
    |> Request.prepend_request_steps(get_metadata_token: &auth_imdsv2/1)
    |> Request.append_response_steps(expose_metadata_token: &expose_metadata_token/1)
  end

  defp auth_imdsv2(%Request{} = request) do
    metadata_token = Request.get_option(request, :metadata_token, nil)
    ttl_seconds = Request.get_option(request, :metadata_token_ttl_seconds, 21600)
    fallback_to_imdsv1 = Request.get_option(request, :fallback_to_imdsv1, false)

    if metadata_token do
      request
      |> Request.put_header("x-aws-ec2-metadata-token", metadata_token)
      |> Request.put_private(:reqimdsv2_metadata_token, metadata_token)
    else
      # Get a new token
      auth_req =
        Req.new(
          method: :put,
          url: "http://169.254.169.254/latest/api/token",
          headers: %{"x-aws-ec2-metadata-token-ttl-seconds" => ttl_seconds},
          adapter: request.adapter
        )

      case Req.put(auth_req) do
        {:ok, resp} ->
          request
          |> Request.put_header("x-aws-ec2-metadata-token", resp.body)
          |> Request.put_private(:reqimdsv2_metadata_token, resp.body)

        {:error, reason} ->
          case fallback_to_imdsv1 do
            true ->
              Logger.warning("Could not fetch metadata token: #{inspect(reason)}. Falling back to IMDSv1")

              request

            false ->
              {Request.halt(request), RuntimeError.exception("Could not fetch metadata token: #{inspect(reason)}")}
          end
      end
    end
  end

  defp expose_metadata_token({%Request{} = request, %Response{} = response}) do
    token = Request.get_private(request, :reqimdsv2_metadata_token, nil)

    if token do
      {request, Response.put_private(response, :reqimdsv2_metadata_token, token)}
    else
      {request, response}
    end
  end

  @doc """
  Extracts the metadata token from a response. This can be used to reuse the token for subsequent requests.
  """
  @spec get_metadata_token(Response.t()) :: String.t() | nil
  def get_metadata_token(%Response{} = response) do
    Response.get_private(response, :reqimdsv2_metadata_token, nil)
  end
end
