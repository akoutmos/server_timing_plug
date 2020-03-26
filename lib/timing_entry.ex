defmodule ServerTimingPlug.TimingEntry do
  @moduledoc false

  alias __MODULE__

  defstruct [:name, :duration, :description]

  def new(name, duration, description) do
    %TimingEntry{
      name: name,
      duration: duration,
      description: description
    }
  end
end
