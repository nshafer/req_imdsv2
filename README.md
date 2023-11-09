# ReqIMDSv2

Provides a way to automatically authenticate Req requests with the Instance Metadata Service on
an Amazon AWS EC2 instance.

It does this by making a request to IMDSv2 to get a token before the main request, then attaches that token
to the request.

## Features

- Integrates easily with [Req](https://hexdocs.pm/req).
- Handles the extra step of fetching and using a metadata token from IMDSv2.
- Fetches the token from the same host as the original request.
- Supports extracting the metadata token for re-use on subsequent requests.
- Can enable `:fallback_to_imdsv1` if desired, in the case that IMDSv2 fails. (highly unlikely.)

## Installation

The package can be installed from [hex.pm](https://hex.pm/packages/req_imdsv2) by adding `req_imdsv2` to
your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:req, "~> 0.4.0"},
    {:req_imdsv2, "~> 0.1.0"}
  ]
end
```

## Documentation

Documentation is available from [hexdocs.pm](https://hexdocs.pm/req_imdsv2).

## Usage

This will work on an instance that has IMDSv2 required, and will not answer to IMDSv1 requests.

```elixir
Req.new(url: "http://169.254.169.254/latest/meta-data/instance-id")
|> ReqIMDSv2.attach()
|> Req.get!().body
"i-1234567890abcdef0"
```

See the `ReqIMDSv2` module for more information and examples.
