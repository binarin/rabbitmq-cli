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


defmodule ListPermissionsCommandTest do
  use ExUnit.Case, async: false
  import TestHelper

  @command RabbitMQ.CLI.Ctl.Commands.ListPermissionsCommand

  @vhost "test1"
  @user "guest"
  @root   "/"
  @default_timeout :infinity

  setup_all do
    RabbitMQ.CLI.Core.Distribution.start()
    :net_kernel.connect_node(get_rabbit_hostname)

    add_vhost @vhost
    set_permissions @user, @vhost, ["^guest-.*", ".*", ".*"]

    on_exit([], fn ->
      delete_vhost @vhost
      :erlang.disconnect_node(get_rabbit_hostname)

    end)

    :ok
  end

  setup context do
    {
      :ok,
      opts: %{
        node: get_rabbit_hostname,
        timeout: context[:test_timeout],
        vhost: "/"
      }
    }
  end

  test "merge_defaults adds default vhost" do
    assert {[], %{vhost: "/"}} == @command.merge_defaults([], %{})
  end

  test "merge_defaults: defaults can be overridden" do
    assert @command.merge_defaults([], %{}) == {[], %{vhost: "/"}}
    assert @command.merge_defaults([], %{vhost: "non_default"}) == {[], %{vhost: "non_default"}}
  end

  test "validate: invalid parameters yield an arg count error" do
    assert @command.validate(["extra"], %{}) == {:validation_failure, :too_many_args}
  end

  test "run: on a bad RabbitMQ node, return a badrpc" do
    target = :jake@thedog
    opts = %{node: :jake@thedog, timeout: :infinity, vhost: "/"}
    :net_kernel.connect_node(target)
    assert @command.run([], opts) == {:badrpc, :nodedown}
  end

  @tag test_timeout: @default_timeout, vhost: @vhost
  test "run: specifying a vhost returns the targeted vhost permissions", context do
    assert @command.run(
      [],
      Map.merge(context[:opts], %{vhost: @vhost})
    ) == [[user: "guest", configure: "^guest-.*", write: ".*", read: ".*"]]
  end

  @tag test_timeout: 30
  test "run: sufficiently long timeouts don't interfere with results", context do
    results = @command.run([], context[:opts])
    Enum.all?([[user: "guest", configure: ".*", write: ".*", read: ".*"]], fn(perm) ->
      Enum.find(results, fn(found) -> found == perm end)
    end)
  end

  @tag test_timeout: 0
  test "run: timeout causes command to return a bad RPC", context do
    assert @command.run([], context[:opts]) ==
      {:badrpc, :timeout}
  end

  @tag vhost: @root
  test "banner", context do
    ctx = Map.merge(context[:opts], %{vhost: @vhost})
    assert @command.banner([], ctx )
      =~ ~r/Listing permissions for vhost \"#{Regex.escape(ctx[:vhost])}\" \.\.\./
  end
end
