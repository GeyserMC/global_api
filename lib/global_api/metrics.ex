defmodule GlobalApi.Metrics do
  @moduledoc false

  alias GlobalApi.CustomMetrics

  def child_spec(opts \\ []) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  def start_link(opts) do
    pid = :erlang.spawn_link(__MODULE__, :init, [opts])
    {:ok, pid}
  end

  def init(_) do
    webhook_url = Application.get_env(:global_api, :webhook)[:url]
    loop(webhook_url, {%{this_hour: 0, this_minute: 1, first_day: true}, %{}, %{open_subscribers: 0}}, 1)
  end

  def loop(webhook_url, state, num) do
    ctm = :os.system_time(:millisecond)

    {last_day, last_minute, open_atm} = state
    if num > 60 do
      {last_day, open_atm} = post_stats(webhook_url, state)
      timeout = 1000 + (ctm - :os.system_time(:millisecond))
      if timeout > 0 do
        :timer.sleep(timeout)
      end
      loop(webhook_url, {last_day, %{}, open_atm}, 1)
    else
      memory = :erlang.memory()
      data = %{
        atoms: :erlang.system_info(:atom_count),
        ports: :erlang.system_info(:port_count),
        processes: :erlang.system_info(:process_count),
        memory: %{
          total: memory[:total] / 1024 / 1024,
          processes: memory[:processes] / 1024 / 1024,
          binary: memory[:binary] / 1024 / 1024,
          code: memory[:code] / 1024 / 1024,
          ets: memory[:ets] / 1024 / 1024
        }
      }
      last_minute = Map.put(last_minute, num, data)
      timeout = 1000 + (ctm - :os.system_time(:millisecond))
      if timeout > 0 do
        :timer.sleep(timeout)
      end
      loop(webhook_url, {last_day, last_minute, open_atm}, num + 1)
    end
  end

  defp post_stats(webhook_url, {last_day, last_minute, open_atm}) do
    all_metrics = CustomMetrics.fetch_all()

    avg = calc_avg(
      last_minute,
      1,
      60,
      %{
        atoms: 0,
        ports: 0,
        processes: 0,
        memory: %{
          total: 0,
          processes: 0,
          binary: 0,
          code: 0,
          ets: 0
        },
      }
    )

    open_atm = %{
      open_atm |
      open_subscribers: open_atm.open_subscribers + (
        all_metrics.subscribers_created + all_metrics.subscribers_added - all_metrics.subscribers_removed)
    }

    open_atm_fields = [
      convert(open_atm, :open_subscribers, "open subscribers")
    ]

    custom_fields = [
      convert(all_metrics, :subscribers_created, "subscribers created"),
      convert(all_metrics, :subscribers_added, "subscribers added"),
      convert(all_metrics, :subscribers_removed, "subscribers removed"),
      convert(all_metrics, :skin_upload_requests, "skin upload requests"),
      convert(all_metrics, :skins_uploaded, "skins uploaded"),
      convert(all_metrics, :get_xuid, "get xuid"),
      convert(all_metrics, :get_gamertag, "get gamertag"),
      convert(all_metrics, :get_java_link, "get java link"),
      convert(all_metrics, :get_bedrock_link, "get bedrock link")
    ]

    this_minute = last_day.this_minute
    this_hour = last_day.this_hour

    hour_count = if last_day.first_day do
      this_hour
    else
      24
    end

    last_day_description = if hour_count == 1 do
      "The amount of requests performed in the last hour"
    else
      "The amount of requests performed in the last #{hour_count} hours"
    end

    {last_day, custom_day_fields} = convert_all(last_day, all_metrics)

    # we need the converted values for the hour metric
    last_hour = get_current_hour(last_day, this_hour)
    last_hour_description = "The number of received requests in the last #{this_minute} minutes"

    time_based_metrics = if last_day.this_hour == 0 && last_day.first_day do
      [
        %{
          description: last_hour_description,
          color: 4886754,
          author: %{
            name: "Global Api Statistics",
            icon_url: "https://geysermc.org/favicon.ico"
          },
          fields: last_hour
        }
      ]
    else
      [
        %{
          description: last_day_description,
          color: 4886754,
          author: %{
            name: "Global Api Statistics",
            icon_url: "https://geysermc.org/favicon.ico"
          },
          fields: custom_day_fields
        },
        %{
          description: last_hour_description,
          color: 4886754,
          fields: last_hour
        }
      ]
    end

    memory = "total: #{avg.memory[:total]} mb
processes: #{avg.memory[:processes]} mb
binary: #{avg.memory[:binary]} mb
code: #{avg.memory[:code]} mb
ets: #{avg.memory[:ets]} mb"

    system_fields = [
      %{
        name: "atoms",
        value: "average: " <> avg.atoms <> "\nlimit: #{:erlang.system_info(:atom_limit)}",
        inline: true
      },
      %{
        name: "ports count",
        value: "average: " <> avg.ports <> "\nlimit: #{:erlang.system_info(:port_limit)}",
        inline: true
      },
      %{
        name: "processes count",
        value: "average: " <> avg.processes <> "\nlimit: #{:erlang.system_info(:process_limit)}",
        inline: true
      },
      %{name: "memory (avg)", value: memory, inline: true},
      %{
        name: "uptime",
        value: calc_time(:erlang.element(1, :erlang.statistics(:wall_clock)), 1),
        inline: true
      },
      %{
        name: "compute time",
        value: calc_time(:erlang.element(1, :erlang.statistics(:runtime)), 1),
        inline: true
      }
    ]

    #todo it's actually quite likely that these requests take one second or more
    # so for the best results we should do this uploading in a separate process
    # since the request is blocking
    HTTPoison.patch(
      webhook_url,
      Jason.encode!(
        %{
          embeds: Enum.concat(
            time_based_metrics,
            [
              %{
                description: "The number of received requests in the last 60 seconds",
                color: 4886754,
                fields: custom_fields
              },
              %{
                description: "The number of open connections at this moment",
                color: 4886754,
                fields: open_atm_fields
              },
              %{
                description: "System information",
                color: 4886754,
                timestamp: DateTime.utc_now()
                           |> DateTime.to_iso8601(),
                fields: system_fields
              }
            ]
          )
        }
      ),
      [{"Content-Type", "application/json"}]
    )

    {last_day, open_atm}
  end

  defp calc_avg(state, num, last_num, total) do
    total = %{
      atoms: add(total, state, num, :atoms),
      ports: add(total, state, num, :ports),
      processes: add(total, state, num, :processes),
      memory: %{
        total: add(total, state, num, :memory, :total),
        processes: add(total, state, num, :memory, :processes),
        binary: add(total, state, num, :memory, :binary),
        code: add(total, state, num, :memory, :code),
        ets: add(total, state, num, :memory, :ets)
      }
    }
    if num >= last_num do
      %{
        atoms: :erlang.float_to_binary(total.atoms / last_num, [decimals: 1]),
        ports: :erlang.float_to_binary(total.ports / last_num, [decimals: 2]),
        processes: :erlang.float_to_binary(total.processes / last_num, [decimals: 1]),
        memory: %{
          total: :erlang.float_to_binary(total.memory[:total] / last_num, [decimals: 2]),
          processes: :erlang.float_to_binary(total.memory[:processes] / last_num, [decimals: 2]),
          binary: :erlang.float_to_binary(total.memory[:binary] / last_num, [decimals: 2]),
          code: :erlang.float_to_binary(total.memory[:code] / last_num, [decimals: 2]),
          ets: :erlang.float_to_binary(total.memory[:ets] / last_num, [decimals: 2]),
        }
      }
    else
      calc_avg(state, num + 1, last_num, total)
    end
  end

  defp convert(all_metrics, metric, name) do
    case all_metrics do
      %{^metric => value} ->
        %{name: name, value: "#{value}", inline: true}
      _ -> %{name: name, value: "error: couldn't find metric #{metric}", inline: true}
    end
  end

  defp convert_all(last_day, all_metrics) do
    hour = last_day.this_hour
    minute = last_day.this_minute

    cur_hour_val = last_day[hour]
    last_day = if cur_hour_val == nil do
      Map.put(last_day, hour, Map.from_struct(all_metrics))
    else
      cur_hour_val = for {key, _} <- cur_hour_val,
                         into: %{},
                         do: {key, Map.get(cur_hour_val, key) + get_value(all_metrics, key, 0)}
      Map.put(last_day, hour, cur_hour_val)
    end

    # we use 25 hours. 24 for display and one for the current hour. (0..24)

    fields = if hour == 0 && last_day.first_day do
      []
    else
      avg_day = calc_avg_day(
        last_day,
        0,
        hour,
        last_day.first_day,
        %{
          subscribers_created: 0,
          subscribers_added: 0,
          subscribers_removed: 0,
          skin_upload_requests: 0,
          skins_uploaded: 0,
          get_xuid: 0,
          get_gamertag: 0,
          get_java_link: 0,
          get_bedrock_link: 0,
        }
      )

      [
        convert(avg_day, :subscribers_created, "subscribers created"),
        convert(avg_day, :subscribers_added, "subscribers added"),
        convert(avg_day, :subscribers_removed, "subscribers removed"),
        convert(avg_day, :skin_upload_requests, "skin upload requests"),
        convert(avg_day, :skins_uploaded, "skins uploaded"),
        convert(avg_day, :get_xuid, "get xuid"),
        convert(avg_day, :get_gamertag, "get gamertag"),
        convert(avg_day, :get_java_link, "get java link"),
        convert(avg_day, :get_bedrock_link, "get bedrock link")
      ]
    end

    if minute >= 60 do
      if hour >= 24 do
        last_day = Map.delete(last_day, 0)
        {%{last_day | this_minute: 1, this_hour: 0, first_day: false}, fields}
      else
        last_day = Map.delete(last_day, hour + 1)
        {%{last_day | this_minute: 1, this_hour: hour + 1}, fields}
      end
    else
      {%{last_day | this_minute: minute + 1}, fields}
    end
  end

  defp get_current_hour(last_day, hour) do
    [
      convert(last_day[hour], :subscribers_created, "subscribers created"),
      convert(last_day[hour], :subscribers_added, "subscribers added"),
      convert(last_day[hour], :subscribers_removed, "subscribers removed"),
      convert(last_day[hour], :skin_upload_requests, "skin upload requests"),
      convert(last_day[hour], :skins_uploaded, "skins uploaded"),
      convert(last_day[hour], :get_xuid, "get xuid"),
      convert(last_day[hour], :get_gamertag, "get gamertag"),
      convert(last_day[hour], :get_java_link, "get java link"),
      convert(last_day[hour], :get_bedrock_link, "get bedrock link")
    ]
  end

  defp calc_avg_day(last_day, num, hour, first_day, total) do
    # protects against the first hour call and allows metrics that run for more then 24 hours
    # to just count from 0..24 and only excluding the hour they're working on now
    if num == hour do
      if first_day do
        total
      else
        if num < 24 do
          calc_avg_day(last_day, num + 1, hour, first_day, total)
        end
      end
    else
      total = %{
        subscribers_created: add(total, last_day, num, :subscribers_created),
        subscribers_added: add(total, last_day, num, :subscribers_added),
        subscribers_removed: add(total, last_day, num, :subscribers_removed),
        skin_upload_requests: add(total, last_day, num, :skin_upload_requests),
        skins_uploaded: add(total, last_day, num, :skins_uploaded),
        get_xuid: add(total, last_day, num, :get_xuid),
        get_gamertag: add(total, last_day, num, :get_gamertag),
        get_java_link: add(total, last_day, num, :get_java_link),
        get_bedrock_link: add(total, last_day, num, :get_bedrock_link),
      }

      # just count from 0..24. The protection in the begin of this function will fix the remaining issues
      if num < 24 do
        calc_avg_day(last_day, num + 1, hour, first_day, total)
      else
        total
      end
    end
  end

  defp get_value(struct, metric, default \\ 0) do
    case struct do
      %{^metric => value} ->
        value
      _ -> default
    end
  end

  defp add(total, state, num, id, sub_id \\ nil) do
    value = state[num][id]
    total = total[id]
    if sub_id !== nil do
      total[sub_id] + value[sub_id]
    else
      total + value
    end
  end

  def calc_time(time, decimals, previous \\ :millisecond) do
    if time > 100 && previous != :day do
      case previous do
        :millisecond ->
          calc_time(time / 1000, decimals, :second)
        :second ->
          calc_time(time / 60, decimals, :minute)
        :minute ->
          calc_time(time / 60, decimals, :hour)
        :hour ->
          calc_time(time / 24, decimals, :day)
        _ ->
          :erlang.float_to_binary(time, [decimals: decimals]) <> " " <> Atom.to_string(previous) <> "#{
            if time > 1 do
              's'
            else
              ''
            end
          }"
      end
    else
      :erlang.float_to_binary(time, [decimals: decimals]) <> " " <> Atom.to_string(previous) <> "#{
        if time > 1 do
          's'
        else
          ''
        end
      }"
    end
  end
end
