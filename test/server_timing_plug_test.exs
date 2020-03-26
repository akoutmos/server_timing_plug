defmodule ServerTimingPlugTest do
  use ExUnit.Case

  alias Plug.Conn

  setup do
    # Setting defaults so all tests start with same state
    System.put_env("SERVER_TIMING_PLUG_ENABLED", "true")
    Application.put_env(:server_timing_plug, :header_unit, :millisecond)
    Application.put_env(:server_timing_plug, :enabled, true)

    %{default_opts: ServerTimingPlug.init([])}
  end

  describe "TelemetryFilter" do
    test "should attach Server-Timing header if config is enabled", %{default_opts: opts} do
      conn = ServerTimingPlug.call(%Conn{}, opts)

      [before_send] = conn.before_send
      ServerTimingPlug.capture_timing("test-event", 55_000_000)

      conn_after_plug = before_send.(conn)

      assert Function.info(before_send, :module) == {:module, ServerTimingPlug}
      assert contains_server_timing_header?(conn_after_plug)
      assert timing_header_equals?(conn_after_plug, "test-event;dur=55")
    end

    test "should not attach Server-Timing header if config is disabled" do
      Application.put_env(:server_timing_plug, :enabled, false)
      opts = ServerTimingPlug.init(enabled: :config)
      conn = ServerTimingPlug.call(%Conn{}, opts)

      [before_send] = conn.before_send
      ServerTimingPlug.capture_timing("test-event", 55_000_000)

      conn_after_plug = before_send.(conn)

      assert Function.info(before_send, :module) == {:module, ServerTimingPlug}
      refute contains_server_timing_header?(conn_after_plug)
    end

    test "should not attach Server-Timing header if env var is disabled" do
      System.put_env("SERVER_TIMING_PLUG_ENABLED", "false")
      opts = ServerTimingPlug.init(enabled: {:system, "SERVER_TIMING_PLUG_ENABLED"})
      conn = ServerTimingPlug.call(%Conn{}, opts)

      [before_send] = conn.before_send
      ServerTimingPlug.capture_timing("test-event", 55_000_000)

      conn_after_plug = before_send.(conn)

      assert Function.info(before_send, :module) == {:module, ServerTimingPlug}
      refute contains_server_timing_header?(conn_after_plug)
    end

    test "should not attach Server-Timing header if opts is disabled" do
      opts = ServerTimingPlug.init(enabled: false)
      conn = ServerTimingPlug.call(%Conn{}, opts)

      [before_send] = conn.before_send
      ServerTimingPlug.capture_timing("test-event", 55_000_000)

      conn_after_plug = before_send.(conn)

      assert Function.info(before_send, :module) == {:module, ServerTimingPlug}
      refute contains_server_timing_header?(conn_after_plug)
    end

    test "should convert the timings to the configured unit if configured" do
      opts = ServerTimingPlug.init(header_unit: :second)
      conn = ServerTimingPlug.call(%Conn{}, opts)

      [before_send] = conn.before_send
      ServerTimingPlug.capture_timing("test-event", {550, :millisecond}, "This is a description")

      conn_after_plug = before_send.(conn)

      assert Function.info(before_send, :module) == {:module, ServerTimingPlug}
      assert contains_server_timing_header?(conn_after_plug)
      assert timing_header_equals?(conn_after_plug, "test-event;desc=\"This is a description\";dur=0.55")
    end

    test "should convert the timings to the configured unit if configured via env var" do
      System.put_env("SERVER_TIMING_PLUG_UNIT", "nanosecond")
      opts = ServerTimingPlug.init(header_unit: {:system, "SERVER_TIMING_PLUG_UNIT"})
      conn = ServerTimingPlug.call(%Conn{}, opts)

      [before_send] = conn.before_send
      ServerTimingPlug.capture_timing("test-event", {550, :millisecond}, "This is a description")

      conn_after_plug = before_send.(conn)

      assert Function.info(before_send, :module) == {:module, ServerTimingPlug}
      assert contains_server_timing_header?(conn_after_plug)
      assert timing_header_equals?(conn_after_plug, "test-event;desc=\"This is a description\";dur=550000000")
    end

    test "should convert the timings to the configured unit if configured via config" do
      Application.put_env(:server_timing_plug, :header_unit, :second)
      opts = ServerTimingPlug.init(header_unit: :config)
      conn = ServerTimingPlug.call(%Conn{}, opts)

      [before_send] = conn.before_send
      ServerTimingPlug.capture_timing("test-event", {5567, :millisecond}, "This is a description")

      conn_after_plug = before_send.(conn)

      assert Function.info(before_send, :module) == {:module, ServerTimingPlug}
      assert contains_server_timing_header?(conn_after_plug)
      assert timing_header_equals?(conn_after_plug, "test-event;desc=\"This is a description\";dur=5.567")
    end

    test "should convert the timings to configured units regardless of input time type", %{default_opts: opts} do
      conn = ServerTimingPlug.call(%Conn{}, opts)

      [before_send] = conn.before_send
      ServerTimingPlug.capture_timing("test-event", {556_742, :microsecond}, "This is a description")
      ServerTimingPlug.capture_timing("test-event", {3, :second}, "This is a description")
      ServerTimingPlug.capture_timing("test-event", {0, :second}, "This is a description")
      ServerTimingPlug.capture_timing("test-event", {10, :microsecond}, "This is a description")
      ServerTimingPlug.capture_timing("test-event", {1, :millisecond}, "This is a description")
      ServerTimingPlug.capture_timing("test-event", {1, :nanosecond}, "This is a description")

      conn_after_plug = before_send.(conn)

      assert Function.info(before_send, :module) == {:module, ServerTimingPlug}
      assert contains_server_timing_header?(conn_after_plug)

      assert timing_header_equals?(
               conn_after_plug,
               "test-event;desc=\"This is a description\";dur=556.742, test-event;desc=\"This is a description\";dur=3000, test-event;desc=\"This is a description\";dur=0, test-event;desc=\"This is a description\";dur=0.01, test-event;desc=\"This is a description\";dur=1, test-event;desc=\"This is a description\";dur=0.000001"
             )
    end

    test "should attach timing descriptions if ServerTimingPlug.capture_timing/3 is called", %{default_opts: opts} do
      conn = ServerTimingPlug.call(%Conn{}, opts)

      [before_send] = conn.before_send
      ServerTimingPlug.capture_timing("test-event", {550, :millisecond}, "This is a description")

      conn_after_plug = before_send.(conn)

      assert Function.info(before_send, :module) == {:module, ServerTimingPlug}
      assert contains_server_timing_header?(conn_after_plug)
      assert timing_header_equals?(conn_after_plug, "test-event;desc=\"This is a description\";dur=550")
    end
  end

  defp contains_server_timing_header?(conn) do
    Conn.get_resp_header(conn, "Server-Timing") != []
  end

  defp timing_header_equals?(conn, expected_value) do
    Conn.get_resp_header(conn, "Server-Timing") == [expected_value]
  end
end
