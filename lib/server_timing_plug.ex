defmodule ServerTimingPlug do
  @moduledoc """
  Documentation for `ServerTimingPlug`.

  Possible config values:
  header_unit: :second | :millisecond | :microsecond | :nanosecond | :native | :config | {:system, "ENV_VAR"}
  enabled: true | false | :config | {:system, "ENV_VAR"}

  Ensure that each captured timing entry has a unique name https://w3c.github.io/server-timing/#the-server-timing-header-field
  """

  @behaviour Plug

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
  Possible values for unit:
  `:second, :millisecond, :microsecond, :nanosecond, :native`
  Use System.convert_time_unit(duration, unit, opts.time_unit)
  """
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
  This function is the callback that is invoked by `register_before_send/2`. It takes in a %Conn{}
  struct, formats the Server-Timing header, attaches the header and then returns the updated
  %Conn{} struct.
  """
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
