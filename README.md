# ReqIMDSv2

Provides a way to automatically authenticate Req requests with the Instance Metadata Service on
an Amazon AWS EC2 instance.

It does this by making a request to IMDSv2 to get a token before the main request, then attaches that token
to the request.

## Features

- Integrates easily with [Req](https://github.com/wojtekmach/req)
- Handles the extra step of fetching and using a metadata token from IMDSv2
- Supports extracting the metadata token for re-use on subsequent requests.
- Can enable `:fallback_to_imdsv1` if desired, in the case that IMDSv2 fails. (highly unlikely)

## Installation

The package can be installed by adding `req_imdsv2` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:req, "~> 0.4.0"},
    {:req_imdsv2, "~> 0.1.0"}
  ]
end
```
## Examples

```elixir
Req.new(url: "http://169.254.169.254/latest/meta-data/instance-id")
|> ReqIMDSv2.attach()
|> Req.get!().body
"i-1234567890abcdef0"
```
