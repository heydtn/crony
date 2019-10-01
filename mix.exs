defmodule Crony.MixProject do
  use Mix.Project

  def project do
    [
      app: :crony,
      version: "0.6.2",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: [main: "Crony", extras: ["README.md"]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :erlexec, :exexec],
      mod: {Crony.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:brex_result, "~> 0.4"},
      {:cowboy, "~> 2.6.3"},
      {:connection, "~> 1.0"},
      {:chrome_remote_interface, "~> 0.4"},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false},
      {:erlexec, "~> 1.10.0"},
      {:ex_doc, "~> 0.20", only: :dev, runtime: false},
      {:exexec, "~> 0.2"},
      {:flow, "~> 0.14"},
      {:jason, "~> 1.1"},
      {:plug, "~> 1.8.0"},
      {:plug_cowboy, "~> 2.0.2"},
      {:poolboy, "~> 1.5"}
    ]
  end

  defp description() do
    "Scalable Chrome Browser pool and proxy service for remote debug protocol connections to managed Headless Chrome instances."
  end

  defp package() do
    [
      name: "Crony",
      files: ["config", "lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Nate Heydt (@heydtn)"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/heydtn/crony"}
    ]
  end
end
