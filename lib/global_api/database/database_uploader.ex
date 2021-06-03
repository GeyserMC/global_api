defmodule GlobalApi.DatabaseUploader do
  @moduledoc false
  require Logger

  alias GlobalApi.DatabaseQueue

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
    DatabaseQueue.resume(self())
    run()
  end

  def run() do
    try do
      receive do
        {:exec, {fn_ref, args}} ->
          apply(fn_ref, args)
          DatabaseQueue.resume(self())
          run()
        {:exit} ->
          DatabaseQueue.exit(self())
      end
    catch
      e ->
        Logger.error(Exception.format(:error, e, __STACKTRACE__))
        run()
    end
  end
end
