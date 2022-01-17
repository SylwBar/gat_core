defmodule GATCoreTest do
  use ExUnit.Case
  doctest GATCore

  test "APRS check #1" do
    assert GATCore.APRS.get_source_id(
             "TEST>OGNSDR,TCPIP*,qAC,GLIDERN1:/161412h1020.30NI01234.56E&/A=000321"
           ) == {:ogn_station, "TEST"}
  end

  test "APRS check #2" do
    assert GATCore.APRS.get_source_id(
             "FLRAABBCC>APRS,qAS,TEST:/123456h1234.56S/12345.67W'123/321/A=123456 !W06! id06AABBCC -355fpm -3.3rot 2.8dB 5e +1.0kHz gps3x3"
           ) == {:ogn_object, {2, "\xAA\xBB\xCC"}, :flarm}
  end
end
