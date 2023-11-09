defmodule ReqIMDSv2Test do
  use ExUnit.Case
  # doctest ReqIMDSv2
  import ExUnit.CaptureLog
  alias Req.Response

  test "fetches token" do
    mock_valid_adapter = fn request ->
      case request.url.path do
        "/latest/api/token" ->
          {request, Response.new(status_code: 200, body: "mock-token")}

        "/latest/meta-data/" ->
          assert request.headers["x-aws-ec2-metadata-token"] == ["mock-token"]
          {request, Response.new(status_code: 200, body: "mock-data")}
      end
    end

    request =
      Req.new(url: "http://169.254.169.254/latest/meta-data/", adapter: mock_valid_adapter)
      |> ReqIMDSv2.attach()

    assert {:ok, resp} = Req.get(request)
    assert "mock-token" == ReqIMDSv2.get_metadata_token(resp)
  end

  test "can reuse metadata token" do
    token = "my-mock-token"

    mock_valid_adapter = fn request ->
      assert request.url.path != "/latest/api/token"
      assert request.headers["x-aws-ec2-metadata-token"] == ["my-mock-token"]
      {request, Response.new(status_code: 200, body: "mock-data")}
    end

    request =
      Req.new(url: "http://169.254.169.254/latest/meta-data/", adapter: mock_valid_adapter)
      |> ReqIMDSv2.attach(metadata_token: token)

    assert {:ok, resp} = Req.get(request)
    assert "my-mock-token" == ReqIMDSv2.get_metadata_token(resp)
  end

  test "errors if can't get metadata token" do
    mock_valid_adapter = fn request ->
      case request.url.path do
        "/latest/api/token" ->
          {request, RuntimeError.exception("mock-error")}

        "/latest/meta-data/" ->
          assert request.headers["x-aws-ec2-metadata-token"] == nil
          {request, Response.new(status_code: 200, body: "mock-data")}
      end
    end

    request =
      Req.new(url: "http://169.254.169.254/latest/meta-data/", adapter: mock_valid_adapter)
      |> ReqIMDSv2.attach()

    assert {:error, %RuntimeError{}} = Req.get(request)
  end

  test "can fallback to IMDSv1 if requested" do
    mock_valid_adapter = fn request ->
      case request.url.path do
        "/latest/api/token" ->
          {request, RuntimeError.exception("mock-error")}

        "/latest/meta-data/" ->
          assert request.headers["x-aws-ec2-metadata-token"] == nil
          {request, Response.new(status_code: 200, body: "mock-data")}
      end
    end

    request =
      Req.new(url: "http://169.254.169.254/latest/meta-data/", adapter: mock_valid_adapter)
      |> ReqIMDSv2.attach(fallback_to_imdsv1: true)

    do_request = fn ->
      assert {:ok, resp} = Req.get(request)
      assert nil == ReqIMDSv2.get_metadata_token(resp)
    end

    log = capture_log(do_request)
    assert log =~ "Falling back to IMDSv1"
  end

  test "fetches token from same host as original request" do
    mock_valid_adapter = fn request ->
      case request.url.path do
        "/latest/api/token" ->
          assert request.url.host == "localhost"
          assert request.url.port == 4000
          {request, Response.new(status_code: 200, body: "mock-token")}

        "/latest/meta-data/" ->
          assert request.url.host == "localhost"
          assert request.url.port == 4000
          {request, Response.new(status_code: 200, body: "mock-data")}
      end
    end

    request =
      Req.new(url: "http://localhost:4000/latest/meta-data/", adapter: mock_valid_adapter)
      |> ReqIMDSv2.attach()

    assert {:ok, resp} = Req.get(request)
    assert "mock-token" == ReqIMDSv2.get_metadata_token(resp)
  end
end
