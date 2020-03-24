defmodule ServerTimingPlug.ConfigOpts do
  @moduledoc """

  """

  alias __MODULE__

  defstruct [:header_unit, :enabled]

  def new(header_unit, enabled) do
    %ConfigOpts{
      header_unit: header_unit,
      enabled: enabled
    }
  end
end
