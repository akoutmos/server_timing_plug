defmodule ServerTimingPlug.MixProject do
  use Mix.Project

  def project do
    [
      app: :server_timing_plug,
      version: "0.1.0",
      elixir: "~> 1.9",
      name: "ServerTimingPlug",
      source_url: "https://github.com/akoutmos/server_timing_plug",
      homepage_url: "https://hex.pm/packages/server_timing_plug",
      description: "Plug that can be used to add Server-Timing header metrics to responses",
      start_permanent: Mix.env() == :prod,
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package() do
    [
      name: "server_timing_plug",
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/akoutmos/server_timing_plug"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.8"},
      {:decimal, "~> 1.7"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
