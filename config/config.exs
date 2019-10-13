# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

envar = fn name ->
  #
  # https://github.com/ueberauth/ueberauth_google/issues/40
  #
  # Detects whether Distillery is currently loaded, which is the behavior when building a release,
  # via mix release, which calls a Distillery task.
  #
  # If Distillery is loaded, then presumably the release will eventually be run with `REPLACE_OS_VARS`
  # defined, which allows the boot script to replace all values in `sys.config` within the release
  # with proper values from the environment. In these cases, emit name of the environment variable
  # wrapped in ${} so the script provided by Distillery can fix them up at boot time.
  #
  # Otherwise it is presumed that the config file is being evaluated outside of running a release.
  # This can happen, for example, during local development or testing. When this is the case,
  # since the configuration is not to be compiled into anything else, it is safe to invoke
  # `System.get_env/1` right away to get the desired value.
  #
  case List.keyfind(Application.loaded_applications(), :distillery, 0) do
    nil -> System.get_env(name)
    _ -> "${#{name}}"
  end
end

config :logger,
       :console,
       metadata: [:request_id, :pid, :module],
       level: :debug

config :crony,
  chrome_remote_debug_port_from: envar.("CRONY_CHROME_PORT_FROM") || "9222",
  chrome_remote_debug_port_to: envar.("CRONY_CHROME_PORT_TO") || "9228"

config :crony, Crony.ProxyListener,
  host: envar.("CRONY_PROXY_HOST") || "127.0.0.1",
  port: envar.("CRONY_PROXY_PORT") || "1331"

config :crony, Crony.ProxyServer, packet_trace: false

config :crony, Crony.Endpoint,
  scheme: :http,
  port: envar.("CRONY_ENDPOINT_PORT") || "1330"

config :crony, Crony.BrowserPool.Browser.Chrome,
  page_wait_ms: envar.("CRONY_CHROME_SERVER_PAGE_WAIT_MS") || "200",
  crash_dumps_dir: envar.("CHROME_CHROME_SERVER_CRASH_DUMPS_DIR") || "/tmp",
  verbose_logging: 0
