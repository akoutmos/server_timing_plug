# ServerTimingPlug

[![Hex.pm](https://img.shields.io/hexpm/v/server_timing_plug.svg)](http://hex.pm/packages/server_timing_plug) [![Build Status](https://travis-ci.org/akoutmos/server_timing_plug.svg?branch=master)](https://travis-ci.org/akoutmos/server_timing_plug)

The purpose of this library is to provide an easy way to capture basic timing metrics from your application and
surface them via the Server-Timing header (https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Server-Timing).
The design of this lib is very much inspired from https://github.com/hauleth/plug_telemetry_server_timing, but makes
some slightly different design decisions. Whereas `plug_telemetry_server_timing` attaches `:telemetry` handlers to
events and automatically aggregates the results of timings, this library allows you to time arbitrary events and
does not infer timing label names based on telemetry events. There are other Server-Timing libraries on hex as well;
Which one you choose depends on your specific needs :).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `server_timing_plug` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:server_timing_plug, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/server_timing_plug](https://hexdocs.pm/server_timing_plug).
