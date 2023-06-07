defmodule EbayXmlApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :ebay_xml_api,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:xml_builder, "~> 2.2"},
      {:sweet_xml, "~> 0.7.1"},
      {:credo, "~> 1.5", only: [:dev], runtime: :false}
    ]
  end
end
