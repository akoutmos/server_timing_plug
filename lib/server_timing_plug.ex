defmodule ServerTimingPlug do
  @moduledoc """
  ServerTimingPlug is a Plug that can be used to generate an HTTP Server-Timing
  header so that your browser can display timing metrics for a given request.
  For more details on Server-Timing see the MDN documentation
  https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Server-Timing.

  ## Usage
  To use ServerTimingPlug in your application, open up your `endpoint.ex` file and
  add the following entry:

  `plug ServerTimingPlug`

  With that in place, you can call `ServerTimingPlug.capture_timing` from anywhere
  within your project, and your timings will be available in your browser's developer
  console when the response is received. An important thing to note here is that
  you must call `ServerTimingPlug.capture_timing` from within the same Phoenix process
  that is handling the request. The reason for this being that `ServerTimingPlug` uses the
  Process Dictionary under the hood and it is only able to add timing entries if
  `ServerTimingPlug.capture_timing` is called from within the same process. Look at the
  function documentation for `ServerTimingPlug.capture_timing/2` and
  `ServerTimingPlug.capture_timing/3` to see how to capture timings. Be sure that each
  captured timing entry has a unique name as per
  https://w3c.github.io/server-timing/#the-server-timing-header-field.

  ## Configuration
  ServerTimingPlug can be configured in a number of ways. It can be statically configured via
  the options passed to it in `endpoint.ex`, it can be configured via environment variables,
  or it can be configured via the application configuration (Elixir's `Config` module).

  To configure ServerTimingPlug via the plug entry, you can do the following:

  `plug ServerTimingPlug, header_unit: :millisecond, enabled: true`

  In this case, `ServerTimingPlug` is statically configured and those are the options that
  will always be in effect. If you want to dynamically control the options (for example
  perhaps you want to have this plug enabled in your Dev/QA/Staging environments but disabled
  in your production environment but still ship the same build artifact), you can do the following:

  `plug ServerTimingPlug, header_unit: :millisecond, enabled: {:system, "SERVER_TIMING_PLUG_ENABLED"}`

  If instead you want to configure ServerTimingPlug via Elixir's `Config`, you can do the following:

  `plug ServerTimingPlug, header_unit: :config, enabled: :config`

  and in your `releases.exs` or `prod.exs` file add the following:

  ```elixir
  config :server_timing_plug, header_unit: :millisecond, enabled: true
  ```

  To summarize, below is a breakdown of all the options along with their possible values:
  - header_unit: The time unit that the Server-Timing header gets converted to
    - `:second`
    - `:millisecond`
    - `:microsecond`
    - `:nanosecond`
    - `:native`
    - `:config`
    - `{:system, "YOUR_ENV_VAR"}`
  - enabled: Is the ServerTimingPlug enabled and capturing timings
    - `true`
    - `false`
    - `:config`
    - `{:system, "YOUR_ENV_VAR"}`
  """

  @behaviour Plug

  @typedoc """
  Valid time units for when calling `capture_timing/2` and `capture_timing/3` with a tuple.

  These are the valid time units that can be passed to `System.convert_time_unit/3` to convert
  the time entry.
  """
  @type timing_unit :: :second | :millisecond | :microsecond | :nanosecond | :native

  require Logger

  alias __MODULE__
  alias Plug.Conn
  alias ServerTimingPlug.{ConfigOpts, TimingEntry}

  @impl true
  def init(opts) do
    header_unit = Keyword.get(opts, :header_unit, :millisecond)
    enabled = Keyword.get(opts, :enabled, true)

    ConfigOpts.new(header_unit, enabled)
  end

  @impl true
  def call(conn, opts) do
    updated_opts =
      opts
      |> resolve_header_unit()
      |> resolve_enabled()

    # Set initial state for request server timings
    Process.put(ServerTimingPlug, {updated_opts, []})

    # Register callback to be called before the conn responds to the request
    Conn.register_before_send(conn, &attach_timings/1)
  end

  @doc """
  Store a server timing entry in the Process Dictionary.

  Below are the arguments that you can pass to `capture_timing/3`:
  - `name`: The name of the timing event. Be sure to use only alphanumeric characters, underscores
  and periods to ensure that the browser can report the timing correctly.
  - `duration`: The time of the event that you want to track. If passing in just an integer, it is
  assumed that is in `:native` time. To specify the unit of measurement for the provided duration,
  use the `{duration, :unit}` form like `{580, :millisecond}` for example.
  - `description` (optional): A more in depth description of your event that you are timing.
  """
  @spec capture_timing(String.t(), integer() | {integer(), timing_unit()}, String.t() | nil) :: :ok
  def capture_timing(name, duration, description \\ nil)

  def capture_timing(name, {duration, unit}, description) do
    case Process.get(ServerTimingPlug) do
      {%ConfigOpts{enabled: true} = opts, timings_list} ->
        updated_timings_list = [TimingEntry.new(name, duration, unit, description) | timings_list]
        Process.put(ServerTimingPlug, {opts, updated_timings_list})
        :ok

      _ ->
        :ok
    end
  end

  def capture_timing(name, duration, description) do
    capture_timing(name, {duration, :native}, description)
  end

  @doc """
  The callback that is invoked by `Plug.Conn.register_before_send/2`.

  Given a `%Plug.Conn{}` struct, `attach_timings/1` formats the timing values
  residing in the Process Dictionary, generates the `Server-Timing` header value,
  attaches the header and then returns the updated `%Plug.Conn{}` struct.
  """
  @spec attach_timings(Plug.Conn.t()) :: Plug.Conn.t()
  def attach_timings(%Conn{} = conn) do
    case Process.get(ServerTimingPlug) do
      {%ConfigOpts{enabled: true} = opts, timings_list} ->
        timing_header =
          timings_list
          |> Enum.reverse()
          |> format_timing_header(opts)

        Conn.put_resp_header(conn, "Server-Timing", timing_header)

      _ ->
        conn
    end
  end

  defp format_timing_header(timings_list, %ConfigOpts{} = opts) do
    timings_list
    |> Enum.map(fn %TimingEntry{} = timing_entry ->
      formatted_duration = System.convert_time_unit(timing_entry.duration, timing_entry.unit, opts.header_unit)

      case timing_entry.description do
        nil -> "#{timing_entry.name};dur=#{formatted_duration}"
        description -> "#{timing_entry.name};desc=\"#{description}\";dur=#{formatted_duration}"
      end
    end)
    |> Enum.join(", ")
  end

  defp resolve_header_unit(%ConfigOpts{header_unit: :config} = opts) do
    header_unit = Application.get_env(:server_timing_plug, :header_unit)
    %{opts | header_unit: header_unit}
  end

  defp resolve_header_unit(%ConfigOpts{header_unit: {:system, env_var}} = opts) do
    header_unit =
      case System.get_env(env_var) do
        "second" -> :second
        "millisecond" -> :millisecond
        "microsecond" -> :microsecond
        "nanosecond" -> :nanosecond
        "native" -> :native
      end

    %{opts | header_unit: header_unit}
  end

  defp resolve_header_unit(opts) do
    opts
  end

  defp resolve_enabled(%ConfigOpts{enabled: :config} = opts) do
    enabled = Application.get_env(:server_timing_plug, :enabled)
    %{opts | enabled: enabled}
  end

  defp resolve_enabled(%ConfigOpts{enabled: {:system, env_var}} = opts) do
    enabled =
      case System.get_env(env_var) do
        "true" -> true
        "false" -> false
      end

    %{opts | enabled: enabled}
  end

  defp resolve_enabled(opts) do
    opts
  end
end
