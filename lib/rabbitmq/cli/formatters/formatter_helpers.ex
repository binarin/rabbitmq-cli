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

defmodule RabbitMQ.CLI.Formatters.FormatterHelpers do
  import RabbitCommon.Records
  use Bitwise

  defmacro is_u8(x) do
    quote do
      (unquote(x) >= 0 and unquote(x) <= 255)
    end
  end

  defmacro is_u16(x) do
    quote do
      (unquote(x) >= 0 and unquote(x) <= 65_535)
    end
  end

  def format_info_item(item, escaped \\ true)
  def format_info_item(map, escaped) when is_map(map) do
    ["\#\{",
     Enum.map(map,
              fn({k, v}) ->
                ["#{escape(k, escaped)} => ", format_info_item(v, escaped)]
              end)
     |> Enum.join(", "),
     "}"]
  end
  def format_info_item(resource(name: name), escaped) do # when Record.is_record(res, :resource) do
    #resource(name: name) = res
    escape(name, escaped)
  end
  def format_info_item({n1, n2, n3, n4} = value, _escaped) when
      is_u8(n1) and is_u8(n2) and is_u8(n3) and is_u8(n4) do
    :rabbit_misc.ntoa(value)
  end
  def format_info_item({k1, k2, k3, k4, k5, k6, k7, k8} = value, _escaped) when
      is_u16(k1) and is_u16(k2) and is_u16(k3) and is_u16(k4) and
      is_u16(k5) and is_u16(k6) and is_u16(k7) and is_u16(k8) do
    :rabbit_misc.ntoa(value)
  end
  def format_info_item(value, _escaped) when is_pid(value) do
    :rabbit_misc.pid_to_string(value)
  end
  def format_info_item(value, escaped) when is_binary(value) do
    escape(value, escaped)
  end
  def format_info_item(value, escaped) when is_atom(value) do
    escape(to_charlist(value), escaped)
  end
  def format_info_item([{key, type, _table_entry_value} | _] =
                          value, escaped) when is_binary(key) and
                                               is_atom(type) do
    :io_lib.format("~1000000000000tp",
                   [prettify_amqp_table(value, escaped)])
  end
  def format_info_item([t | _] = value, escaped)
  when is_tuple(t) or is_pid(t) or is_binary(t) or is_atom(t) or is_list(t) do
    ["[",
       Enum.map(value,
                fn(el) ->
                  format_info_item(el, escaped)
                end)
       |> Enum.join(", "),
       "]"]
  end
  def format_info_item({key, value}, escaped) do
    ["{" , :io_lib.format("~p", [key]), ", ",
     format_info_item(value, escaped), "}"]
  end
  def format_info_item(value, _escaped) do
    :io_lib.format("~1000000000000tp", [value])
  end

  defp prettify_amqp_table(table, escaped) do
    for {k, t, v} <- table do
      {escape(k, escaped), prettify_typed_amqp_value(t, v, escaped)}
    end
  end

  defp prettify_typed_amqp_value(:longstr, value, escaped) do
    escape(value, escaped)
  end
  defp prettify_typed_amqp_value(:table, value, escaped) do
    prettify_amqp_table(value, escaped)
  end
  defp prettify_typed_amqp_value(:array, value, escaped) do
    for {t, v} <- value, do: prettify_typed_amqp_value(t, v, escaped)
  end
  defp prettify_typed_amqp_value(_type, value, _escaped) do
    value
  end


  defp escape(atom, escaped) when is_atom(atom) do
    escape(to_charlist(atom), escaped)
  end
  defp escape(bin, escaped)  when is_binary(bin) do
    escape(to_charlist(bin), escaped)
  end
  defp escape(l, false) when is_list(l) do
    escape_char(:lists.reverse(l), [])
  end
  defp escape(l, true) when is_list(l) do
    l
  end

  defp escape_char([?\\ | t], acc) do
    escape_char(t, [?\\, ?\\ | acc])
  end
  defp escape_char([x | t], acc) when x >= 32 and x != 127 do
    escape_char(t, [x | acc])
  end
  defp escape_char([x | t], acc) do
    escape_char(t, [?\\, ?0 + (x >>> 6), ?0 + (x &&& 0o070 >>> 3),
                    ?0 + (x &&& 7) | acc])
  end
  defp escape_char([], acc) do
    acc
  end
end