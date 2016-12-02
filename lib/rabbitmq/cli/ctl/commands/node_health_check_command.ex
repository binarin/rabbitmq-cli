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

defmodule RabbitMQ.CLI.Ctl.Commands.NodeHealthCheckCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour

  @default_timeout 20_000

  def scopes(), do: [:ctl, :diagnostics]

  def validate(args, _) when length(args) > 0, do: {:validation_failure, :too_many_args}
  def validate([], _), do: :ok

  def merge_defaults(args, opts) do
    timeout = case opts[:timeout] do
      nil       -> @default_timeout;
      :infinity -> @default_timeout;
      other     -> other
    end
    minimal = case opts[:minimal] do
      false -> false;
      _     -> true
    end
    {args, Map.merge(opts, %{timeout: timeout, minimal: minimal})}
  end

  def switches(), do: [minimal: :boolean]
  def aliases(), do: [m: :minimal]

  def usage, do: "node_health_check"

  def banner(_, %{node: node_name, timeout: timeout}) do
    ["Timeout: #{timeout / 1000} seconds ...",
     "Checking health of node #{node_name} ..."]
  end

  def run([], %{node: node_name, timeout: timeout, minimal: minimal}) do
    health_check_stream = :rabbit_health_check.health_checks()
    |> Stream.transform(:ok,
      fn
      (check, :ok) ->
        result = run_health_check(node_name, timeout, check)
        {[{check, result}], result};
      (_, err) ->
        {:halt, err}
      end)

    case minimal do
      true ->
        ## Reduce a stream to :ok or error
        Enum.reduce_while(health_check_stream, :ok,
                          fn({_check, :ok}, :ok) -> {:cont, :ok};
                            ({check, err}, :ok) -> {:halt, {check, err}}
                          end);
      false ->
        {:stream, health_check_stream}
    end
  end

  defp run_health_check(node, timeout, check) do
    case :rabbit_health_check.node_health_check(node, timeout, check) do
      :ok                                      ->
        :ok
      true                                     ->
        :ok
      {:badrpc, _} = err                       ->
        err
      {:error_string, error_message}           ->
        {:healthcheck_failed, error_message}
      {:node_is_ko, error_message, _exit_code} ->
        {:healthcheck_failed, error_message}
      other                                    ->
        other
    end
  end

  def output(:ok, _) do
    {:ok, "Health check passed"}
  end
  def output({check, {:healthcheck_failed, message}}, _) do
    {:error, RabbitMQ.CLI.Core.ExitCodes.exit_software,
     healthcheck_failed_message(check, message)}
  end
  def output({check, {:badrpc, :timeout}}, %{timeout: timeout}) do
    {:error, RabbitMQ.CLI.Core.ExitCodes.exit_software,
     timeout_message(check, timeout)}
  end
  def output({check, {:badrpc, :nodedown}}, _) do
    {:error, RabbitMQ.CLI.Core.ExitCodes.exit_software,
     node_down_message(check)}
  end
  def output({:stream, stream}, opts) do
    {:stream,
     Stream.map(stream,
                fn({check, :ok}) ->
                    {check, :ok};
                  ({check, {:healthcheck_failed, message}}) ->
                    {:error, healthcheck_failed_message(check, message)};
                  ({check, {:badrpc, :timeout}}) ->
                    {:error, timeout_message(check, opts[:timeout])}
                  ({check, {:badrpc, :nodedown}}) ->
                    {:error, node_down_message(check)}
                  ({check, error}) ->
                    {:error, generic_error_message(check, error)}
                end)}
  end
  def output({check, error}, _opts) do
    {:error, RabbitMQ.CLI.Core.ExitCodes.exit_software,
     generic_error_message(check, error)}
  end
  use RabbitMQ.CLI.DefaultOutput

  defp timeout_message(check, timeout) do
    "Error: #{check} healthcheck timed out. Timeout: #{timeout}"
  end
  defp healthcheck_failed_message(check, message) do
    "Error: #{check} healthcheck failed. Message: #{message}"
  end
  defp node_down_message(check) do
    "Error: #{check} healthcheck failed. Node is not running"
  end
  defp generic_error_message(check, error) do
    "Error: #{check} healthcheck failed. Error: #{inspect(error)}"
  end
end
