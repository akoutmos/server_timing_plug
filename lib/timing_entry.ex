defmodule ServerTimingPlug.TimingEntry do
  @moduledoc """

  """

  alias __MODULE__

  defstruct [:name, :duration, :unit, :description]

  def new(name, duration, unit, description) do
    %TimingEntry{
      name: name,
      duration: duration,
      unit: unit,
      description: description
    }
  end
end
