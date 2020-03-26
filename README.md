# ServerTimingPlug

[![Hex.pm](https://img.shields.io/hexpm/v/server_timing_plug.svg)](http://hex.pm/packages/server_timing_plug) [![Build Status](https://travis-ci.org/akoutmos/server_timing_plug.svg?branch=master)](https://travis-ci.org/akoutmos/server_timing_plug)

The purpose of this library is to provide an easy way to capture basic timing metrics from your application and
surface them via the Server-Timing header (https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Server-Timing).

## Installation

The package can be installed by adding `server_timing_plug` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:server_timing_plug, "~> 0.1.0"}
  ]
end
```

## Basic Usage

To use ServerTimingPlug in your application, open up your `endpoint.ex` file and add the following entry (shown
with default configuration):

```elixir
plug ServerTimingPlug, header_unit: :millisecond, enabled: true
```

Once that entry has been added to you `endpoint.ex` file, you can simple call `ServerTimingPlug.capture_timing/3` and
`ServerTimingPlug.capture_timing/3` throughout your code in order to capture timings. The captured timings will
be flushed when the response goes out. It is important to note that timings will only be available if the call to
`ServerTimingPlug.capture_timing` is made in the same process as the process that is handling the request. A sample
timing capture could look something like this:

```elixir
def index(conn, params) do
  start_time = System.monotonic_time()

  #
  # Something expensive is done here
  #

  duration = System.monotonic_time() - start_time

  ServerTimingPlug.capture_timing("expensive-thing", duration, "This timing captures the expensive operation")

  json(conn, "{message: "All is well!"}")
end
```

## Additional Thoughts

The design of this lib draws inspired from https://github.com/hauleth/plug_telemetry_server_timing, but makes
some slightly different design decisions. Whereas `plug_telemetry_server_timing` attaches `:telemetry` handlers to
events and automatically aggregates the results of timings, this library allows you to time arbitrary events and
does not infer timing label names based on telemetry events. There are other Server-Timing libraries on hex as well;
Which one you choose depends on your specific needs :).
