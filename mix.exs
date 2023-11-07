defmodule ReqIMDSv2.MixProject do
  use Mix.Project

  def project do
    [
      app: :req_imdsv2,
      version: "0.1.1",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      description: description(),
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "A Req plugin for authenticating with AWS IMDSv2"
  end

  defp package do
    [
      description: "A Req plugin for authenticating with AWS IMDSv2",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/nshafer/req_imdsv2"}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: "https://github.com/nshafer/req_imdsv2"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, ">= 0.4.0"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end
end
