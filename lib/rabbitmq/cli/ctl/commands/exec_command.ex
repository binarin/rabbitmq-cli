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


defmodule RabbitMQ.CLI.Ctl.Commands.ExecCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour
  use RabbitMQ.CLI.DefaultOutput

  def merge_defaults(args, opts), do: {args, opts}

  def formatter(), do: RabbitMQ.CLI.Formatters.Inspect

  def validate([], _) do
    {:validation_failure, :not_enough_args}
  end

  def validate(args, _) when length(args) > 1 do
    {:validation_failure, :too_many_args}
  end

  def validate([""], _) do
    {:validation_failure, "Expression must not be blank"}
  end

  def validate([_], _), do: :ok

  def run([expr], %{} = opts) do
    {val, _} = Code.eval_string(expr, [options: opts])
    {:ok, val}
  end

  def usage, do: "exec <expr>"

  def banner(_, _), do: nil

end
