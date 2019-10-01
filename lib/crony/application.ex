defmodule Crony.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    # HACK to get exec running as root.
    Application.put_env(:exec, :root, true)
    {:ok, _} = Application.ensure_all_started(:erlexec)

    children = [
      Crony.ChromeServer.child_spec()
    ]

    elixir_version = System.version()
    otp_release = :erlang.system_info(:otp_release)
    Logger.info("Started application: Elixir `#{elixir_version}` on OTP `#{otp_release}`.")

    opts = [strategy: :one_for_one, name: Crony.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
