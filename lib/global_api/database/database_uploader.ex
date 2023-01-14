defmodule GlobalApi.DatabaseUploader do
  @moduledoc false
  require Logger

  alias GlobalApi.DatabaseQueue
  alias GlobalApi.Utils

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start, [opts]}
    }
  end

  def start(init_arg) do
    {:ok, :erlang.spawn(__MODULE__, :init, [init_arg])}
  end

  def init(_) do
    continue()
  end

  def run() do
      receive do
        {:exec, {fn_ref, args}} ->
          try_apply(fn_ref, args, 0)
        {:exit} ->
          DatabaseQueue.exit(self())
      end
  end

  def try_apply(fn_ref, args, try_number) when try_number < 15 do
    try do
      apply(fn_ref, args)
      continue()
    catch
      _, error ->
        stacktrace = if Utils.environment() == :dev do __STACKTRACE__ else [] end
        Logger.error("try number: #{try_number}. Exception: #{Exception.format(:error, error, stacktrace)}")
        :timer.sleep(1000)
        try_apply(fn_ref, args, try_number + 1)
    end
  end

  # we can't try it indefinitely
  def try_apply(_fn_ref, _args, _try_number), do: continue()

  def continue() do
    DatabaseQueue.resume(self())
    run()
  end
end
