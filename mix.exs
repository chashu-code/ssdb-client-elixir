defmodule SSDB.Mixfile do
  use Mix.Project

  def project do
    [app: :ssdb,
     version: "0.0.2",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    apps = [:exlager]
    mod = {:mod, {SSDB, []} }

    case Mix.env do
      :test ->
        [{:applications, apps}]
      _ ->
        [{:applications, apps}, mod]
    end
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      { :exlager, git: "https://github.com/khia/exlager.git"}
    ]
  end
end
