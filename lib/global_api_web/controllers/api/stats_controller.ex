defmodule GlobalApiWeb.Api.StatsController do
  use GlobalApiWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GlobalApi.SkinPreQueue
  alias GlobalApi.SkinsRepo
  alias GlobalApi.SkinUploadQueue
  alias GlobalApiWeb.Schemas

  @sample_length 300 # skins uploaded in the last x seconds

  tags ["stats"]

  operation :get_all_stats,
    summary: "Get all publicly available Global Api statistics",
    responses: [
      ok: {"Statistics", "application/json", Schemas.Statistics}
    ]

  def get_all_stats(conn, _) do
    {_, {pre_upload_queue_length, upload_queue_length, upload_queue_est_duration}} =
      with {:commit, result} <- Cachex.fetch(
        :general,
        :stats,
        fn _ ->
          pre_upload_queue_length = SkinPreQueue.queue_length()
          upload_queue_length = SkinUploadQueue.queue_length()

          {_, upload_queue_est_duration} =
            with {:commit, result} <- Cachex.fetch(
              :general,
              :upload_queue_est_duration,
              fn _ ->
                {
                  :commit,
                  upload_queue_length * (@sample_length / SkinsRepo.get_recently_uploaded(@sample_length))
                }
              end
            ) do
              Cachex.expire(:general, :upload_queue_est_duration, 15 * 1000)
              {:commit, result}
            end

          {:commit, {pre_upload_queue_length, upload_queue_length, upload_queue_est_duration}}
        end
      ) do
        Cachex.expire(:general, :stats, 6 * 1000)
        {:commit, result}
      end

    json(
      conn,
      %{
        pre_upload_queue: %{
          length: pre_upload_queue_length
        },
        upload_queue: %{
          length: upload_queue_length,
          estimated_duration: upload_queue_est_duration
        }
      }
    )
  end
end
