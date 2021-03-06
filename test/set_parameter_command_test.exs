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


defmodule SetParameterCommandTest do
  use ExUnit.Case, async: false
  import TestHelper

  @command RabbitMQ.CLI.Ctl.Commands.SetParameterCommand

  @vhost "test1"
  @user "guest"
  @root   "/"
  @component_name "federation-upstream"
  @key "reconnect-delay"
  @value "{\"uri\":\"amqp://\"}"

  setup_all do
    RabbitMQ.CLI.Core.Distribution.start()
    :net_kernel.connect_node(get_rabbit_hostname)

    add_vhost @vhost

    enable_federation_plugin()

    on_exit([], fn ->
      delete_vhost @vhost
      :erlang.disconnect_node(get_rabbit_hostname)

    end)

    :ok
  end

  setup context do

    on_exit(context, fn ->
      clear_parameter context[:vhost], context[:component_name], context[:key]
    end)

    {
      :ok,
      opts: %{
        node: get_rabbit_hostname,
        vhost: "/"
      }
    }
  end

  @tag component_name: @component_name, key: @key, value: @value, vhost: @root
  test "merge_defaults: a well-formed command with no vhost runs against the default" do
    assert match?({_, %{vhost: "/"}}, @command.merge_defaults([], %{}))
  end

  test "validate: wrong number of arguments leads to an arg count error" do
    assert @command.validate([], %{}) == {:validation_failure, :not_enough_args}
    assert @command.validate(["insufficient"], %{}) == {:validation_failure, :not_enough_args}
    assert @command.validate(["not", "enough"], %{}) == {:validation_failure, :not_enough_args}
    assert @command.validate(["this", "is", "too", "many"], %{}) == {:validation_failure, :too_many_args}
  end

  @tag component_name: @component_name, key: @key, value: @value, vhost: @vhost
  test "run: a well-formed, host-specific command returns okay", context do
    vhost_opts = Map.merge(context[:opts], %{vhost: context[:vhost]})

    assert @command.run(
      [context[:component_name], context[:key], context[:value]],
      vhost_opts
    ) == :ok

    assert_parameter_fields(context)
  end

  test "run: An invalid rabbitmq node throws a badrpc" do
    target = :jake@thedog
    :net_kernel.connect_node(target)
    opts = %{node: target, vhost: "/"}

    assert @command.run([@component_name, @key, @value], opts) == {:badrpc, :nodedown}
  end

  @tag component_name: "bad-component-name", key: @key, value: @value, vhost: @root
  test "run: an invalid component_name returns a validation failed error", context do
    assert @command.run(
      [context[:component_name], context[:key], context[:value]],
      context[:opts]
    ) == {:error_string, 'Validation failed\n\ncomponent #{context[:component_name]} not found\n'}

    assert list_parameters(context[:vhost]) == []
  end

  @tag component_name: @component_name, key: @key, value: @value, vhost: "bad-vhost"
  test "run: an invalid vhost returns a no-such-vhost error", context do
    vhost_opts = Map.merge(context[:opts], %{vhost: context[:vhost]})

    assert @command.run(
      [context[:component_name], context[:key], context[:value]],
      vhost_opts
    ) == {:error, {:no_such_vhost, context[:vhost]}}
  end

  @tag component_name: @component_name, key: @key, value: "bad-value", vhost: @root
  test "run: an invalid value returns a JSON decoding error", context do
    assert @command.run(
      [context[:component_name], context[:key], context[:value]],
      context[:opts]
    ) == {:error_string, 'JSON decoding error'}

    assert list_parameters(context[:vhost]) == []
  end

  @tag component_name: @component_name, key: @key, value: "{}", vhost: @root
  test "run: an empty JSON object value returns a key \"uri\" not found error", context do
    assert @command.run(
      [context[:component_name], context[:key], context[:value]],
      context[:opts]
    ) == {:error_string, 'Validation failed\n\nKey "uri" not found in reconnect-delay\n'}

    assert list_parameters(context[:vhost]) == []
  end

  @tag component_name: @component_name, key: @key, value: @value, vhost: @vhost
  test "banner", context do
    vhost_opts = Map.merge(context[:opts], %{vhost: context[:vhost]})

    assert @command.banner([context[:component_name], context[:key], context[:value]], vhost_opts)
      =~ ~r/Setting runtime parameter \"#{context[:component_name]}\" for component \"#{context[:key]}\" to \"#{context[:value]}\" \.\.\./
  end

  # Checks each element of the first parameter against the expected context values
  defp assert_parameter_fields(context) do
    result_param = context[:vhost] |> list_parameters |> List.first

    assert result_param[:value] == context[:value]
    assert result_param[:vhost] == context[:vhost]
    assert result_param[:component] == context[:component_name]
    assert result_param[:name] == context[:key]
  end
end
