defmodule OGNCoreTest do
  use ExUnit.Case
  doctest OGNCore

  test "APRS check" do
    assert OGNCore.APRS.get_source_id(
             "TEST>OGNSDR,TCPIP*,qAC,GLIDERN1:/161412h1020.30NI01234.56E&/A=000321"
           ) == {:station, "TEST"}
  end
end
