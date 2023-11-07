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

  * `:metadata_token` - A token to use for authentication. If not provided, a new token will be fetched from the
      IMDSv2 service. See `get_metadata_token/1` for more info on extracting a token from a response.
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
        "ip-10-0-1-1.us-west-1.compute.internal"

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
      # We were given a token, so just attach it and skip the PUT request. If it's invalid, then the request will fail.
      put_token(request, metadata_token)
    else
      # Get a new token with a PUT request to the token endpoint. Use the same adapter as the original request.
      auth_req =
        Req.new(
          url: "http://169.254.169.254/latest/api/token",
          headers: %{"x-aws-ec2-metadata-token-ttl-seconds" => ttl_seconds},
          adapter: request.adapter
        )

      case Req.put(auth_req) do
        {:ok, resp} ->
          put_token(request, resp.body)

        {:error, reason} ->
          # There was an error getting a new token (should be rare.) So we can either fall back to IMDSv1 or fail.
          # Falling back to IMDSv1 just means continuing with the request as-is, with no token attached. This will
          # fail if IMDSv2 is required on the instance.
          if fallback_to_imdsv1 do
            Logger.warning("Could not fetch metadata token: #{inspect(reason)}. Falling back to IMDSv1")
            request
          else
            {Request.halt(request), RuntimeError.exception("Could not fetch metadata token: #{inspect(reason)}")}
          end
      end
    end
  end

  # Put the token in the headers of the request, as well as attach it to private data so it can be extracted later.
  defp put_token(%Request{} = request, token) do
    request
    |> Request.put_header("x-aws-ec2-metadata-token", token)
    |> Request.put_private(:reqimdsv2_metadata_token, token)
  end

  # Extract the token from the request and attach it to the response so it can be extracted later.
  defp expose_metadata_token({%Request{} = request, %Response{} = response}) do
    token = Request.get_private(request, :reqimdsv2_metadata_token, nil)

    if token do
      {request, Response.put_private(response, :reqimdsv2_metadata_token, token)}
    else
      {request, response}
    end
  end

  @doc """
  Extracts the metadata token from a response.

  This can be used to reuse the token for subsequent requests. Returns `nil` if the token is not present, such as if
  the token request failed and the request fell back to IMDSv1.

  ## Example

        req =
          Req.new(url: "http://169.254.169.254/latest/meta-data/instance-id")
          |> ReqIMDSv2.attach(req)
        {:ok, resp} = Req.get(req)
        token = ReqIMDSv2.get_metadata_token(resp)
  """
  @spec get_metadata_token(Response.t()) :: String.t() | nil
  def get_metadata_token(%Response{} = response) do
    Response.get_private(response, :reqimdsv2_metadata_token, nil)
  end
end
