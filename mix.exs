defmodule ChromeRemoteInterface.Mixfile do
  use Mix.Project

  def project do
    [
      app: :chrome_remote_interface,
      version: "0.4.1",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Chrome Remote Interface",
      source_url: "https://github.com/andrewvy/chrome-remote-interface",
      description: description(),
      package: package(),
      dialyzer: dialyzer()
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
      {:jason, "~> 1.1"},
      {:hackney, "~> 1.8 or ~> 1.7 or ~> 1.6"},
      {:websockex, "~> 0.4.0"},
      {:ex_doc, "~> 0.28", only: :dev},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "Chrome Debugging Protocol client for Elixir"
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      plt_add_files: [
        "priv/**/*.ex",
        "test/**/*.ex"
      ],
      ignore_warnings: ".dialyzer_ignore.exs",
      list_unused_filters: true
    ]
  end

  defp package do
    [
      maintainers: ["andrew@andrewvy.com"],
      licenses: ["MIT"],
      links: %{
        "Github" => "https://github.com/andrewvy/chrome-remote-interface"
      }
    ]
  end
end
