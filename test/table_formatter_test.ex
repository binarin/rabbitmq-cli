## The contents of this file are subject to the Mozilla Public License
## Version 1.1 (the "License"); you may not use this file except in
## compliance with the License. You may obtain a copy of the License
## at http://www.mozilla.org/MPL/
##
## Software distributed under the License is distributed on an "AS IS"
## basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
## the License for the specific language governing rights and
## limitations under the License.
##
## The Original Code is RabbitMQ.
##
## The Initial Developer of the Original Code is GoPivotal, Inc.
## Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.


defmodule TableFormatterTest do
  use ExUnit.Case, async: false
  import TestHelper

  @formatter RabbitMQ.CLI.Formatters.Table

  test "string error is returned as is" do
    assert @formatter.format_error("error", %{}) == "error"
  end

  test "non-string error is returned with inspect" do
    assert @formatter.format_error(123, %{}) == "123"
    assert @formatter.format_error({:error, "error"}, %{}) == "{:error, \"error\"}"
    assert @formatter.format_error(:atom_error, %{}) == ":atom_error"
    assert @formatter.format_error([1,2,3], %{}) == "[1, 2, 3]"
  end

  test "formats map with tabs" do
    assert @formatter.format_output(%{a: :apple, b: :beer}, %{}) == "apple\tbeer"
    assert @formatter.format_output(%{a: :apple, b: :beer, c: 1}, %{}) == "apple\tbeer\t1"
    assert @formatter.format_output(%{a: "apple", b: 'beer', c: 1}, %{}) == "apple\tbeer\t1"
  end

  test "format not string values with inspect recursively" do
    assert @formatter.format_output(%{a: :apple, b: "beer", c: {:carp, "fish"}, d: [door: :way], e: %{elk: "horn", for: :you}}, %{}) ==
        "apple\tbeer\t{carp, fish}\t[{door, way}]\t\#{elk => horn, for => you}"

    assert @formatter.format_output(%{a: :apple, b: "beer", c: {:carp, {:small, :fish}}, d: [door: {:way, "big"}], e: %{elk: [horn: :big]}}, %{}) ==
        "apple\tbeer\t{carp, {small, fish}}\t[{door, {way, big}}]\t\#{elk => [{horn, big}]}"
  end
end