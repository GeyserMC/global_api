defmodule GlobalApi.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  alias GlobalApi.Utils
  alias TelemetryMetricsStatsd.Formatter.Datadog

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    host = Utils.get_env(:telemetry, :host)
    port = Utils.get_env(:telemetry, :port)
    server_id = Utils.get_env(:telemetry, :server_id)

    ip = String.split(host, ".", parts: 4)

    host = if length(ip) == 4,
              do: {
                String.to_integer(Enum.at(ip, 0)),
                String.to_integer(Enum.at(ip, 1)),
                String.to_integer(Enum.at(ip, 2)),
                String.to_integer(Enum.at(ip, 3))
              },
              else: host

    children = [
      {
        TelemetryMetricsStatsd,
        metrics: metrics(),
        formatter: :datadog,
        host: host,
        port: port,
        global_tags: [
          server_id: server_id
        ]
      }
    ]

    result = Supervisor.init(children, strategy: :one_for_one)
    startup_stuff(host, port, server_id)
    result
  end

  defp metrics do
    [
      # VM Metrics

      # total = processes + system
      last_value("vm.memory.total", unit: :byte, tags: [:server_id]),
      last_value("vm.memory.processes", unit: :byte, tags: [:server_id]),
      last_value("vm.memory.system", unit: :byte, tags: [:server_id]),
      # system = atom + binary + code + ets + some unmentioned stuff
      last_value("vm.memory.atom", unit: :byte, tags: [:server_id]),
      last_value("vm.memory.binary", unit: :byte, tags: [:server_id]),
      last_value("vm.memory.code", unit: :byte, tags: [:server_id]),
      last_value("vm.memory.ets", unit: :byte, tags: [:server_id]),

      last_value("vm.total_run_queue_lengths.total", tags: [:server_id]),
      last_value("vm.total_run_queue_lengths.cpu", tags: [:server_id]),
      last_value("vm.total_run_queue_lengths.io", tags: [:server_id]),

      last_value("vm.system_counts.process_count", tags: [:server_id]),
      last_value("vm.system_counts.atom_count", tags: [:server_id]),
      last_value("vm.system_counts.port_count", tags: [:server_id]),

      # Database Metrics

      # time spend executing queries
      summary(
        "global_api.repo.query.total_time",
        unit: {:native, :millisecond},
        tag_values: &__MODULE__.query_metatdata/1,
        tags: [:source, :command, :server_id]
      ),
      # query count
      counter(
        "global_api.repo.query.count",
        tag_values: &__MODULE__.query_metatdata/1,
        tags: [:source, :command, :server_id]
      ),

      # Phoenix Metrics

      # time between receiving request and sending response
      summary(
        "phoenix.router_dispatch.stop.duration",
        unit: {:native, :millisecond},
        tag_values: &__MODULE__.endpoint_duration_metadata/1,
        tags: [:route, :status, :server_id]
      ),
      # response count
      counter(
        "phoenix.router_dispatch.stop.count",
        tag_values: &__MODULE__.endpoint_metadata/1,
        tags: [:method, :route, :status, :server_id]
      ),
      # errors returned count
      counter(
        "phoenix.error_rendered.count",
        tag_values: &__MODULE__.error_request_metadata/1,
        tags: [:method, :request_path, :status, :server_id]
      ),

      # Global Api metrics

      # queues
      last_value("global_api.metrics.queues.skin_pre_queue.length", tags: [:server_id]),
      last_value("global_api.metrics.queues.skin_queue.length", tags: [:server_id]),
      last_value("global_api.metrics.queues.db_queue.length", tags: [:server_id]),
      last_value("global_api.metrics.queues.db_queue_pool.count", tags: [:server_id]),

      counter("global_api.metrics.skins.skin_uploaded.count", tags: [:server_id]),
      counter("global_api.metrics.skins.player_updated.count", tags: [:server_id]),
      # player skin updated
      counter("global_api.metrics.skins.new_player.count", tags: [:server_id])
    ]
  end

  def error_request_metadata(
        %{
          conn: %{
            method: method,
            request_path: request_path
          },
          status: status
        }
      ) do
    # it even has a stacktrace that we could use!
    %{method: method, request_path: request_path, status: status}
  end

  def endpoint_duration_metadata(
        %{
          conn: %{
            status: status
          },
          route: route
        }
      ) do
    %{status: status, route: route}
  end

  def endpoint_metadata(
        %{
          conn: %{
            method: method,
            status: status
          },
          route: route
        }
      ) do
    %{method: method, status: status, route: route}
  end


  # Postgres
  def query_metatdata(%{source: source, result: {_, %{command: command}}}) do
    %{source: source, command: command}
  end
  # MyXQL
  def query_metatdata(%{source: source, query: query}) do
    case String.split(query, " ", parts: 2) do
      [head, _] -> %{source: source, command: String.downcase(head)}
      [_] -> %{source: source, command: :unknown}
    end
  end

  def startup_stuff(host, port, server_id) do
    host = to_charlist(host)
    case :gen_udp.open(0, [active: false]) do
      {:ok, socket} ->
        tags = [server_id: server_id]

        # broadcast that this server is online
        write_stat(socket, host, port, format_stat(counter("global_api.servers"), server_id, tags), 1)

        # 'hack' to reset some timers after a restart, because I disabled 'delete_gauges' in Telegraf
        write_stat(socket, host, port, "global_api.metrics.queues.skin_pre_queue.length", 0, tags)
        write_stat(socket, host, port, "global_api.metrics.queues.skin_queue.length", 0, tags)
        write_stat(socket, host, port, "global_api.metrics.queues.db_queue.length", 0, tags)

        :gen_udp.close(socket)
    end
  end

  defp write_stat(socket, host, port, measurement, value, tags) do
    write_stat(socket, host, port, format_stat(last_value(measurement), value, tags), 1)
  end

  # UDP packets aren't guaranteed to come over, so let's just try it 3 times to almost guaranty that the reset comes over
  defp write_stat(socket, host, port, value, try_num) when try_num <= 3 do
    :ok = :gen_udp.send(socket, host, port, value)
    write_stat(socket, host, port, value, try_num + 1)
  end
  defp write_stat(_socket, _host, _port, _value, _try_num), do: :ok

  defp format_stat(metric, value, tags) do
    Datadog.format(metric, value, tags)
    |> :erlang.iolist_to_binary()
  end
end
