# Sidekiq <-> Redis. Prod points REDIS_URL at the redis:7-alpine accessory; dev uses a separate DB
# index so its queue never collides with prod's on the shared localhost:6379 instance.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }

  # Crash recovery (, simplified per F0: a 1000x bootstrap is ~6 min, so re-running a whole interrupted
  # run is cheaper than checkpoint machinery). On worker boot, any run still marked 'running' has no live
  # worker (its R process group was reaped on shutdown) - requeue the whole run from scratch.
  config.on(:startup) do
    # Guard: on a fresh prod the worker may boot before the web role has run the migration.
    if ActiveRecord::Base.connection.table_exists?("analysis_runs")
      AnalysisRun.where(status: "running").find_each do |run|
        run.update_columns(status: "pending", progress: 0, started_at: nil)
        PvarJob.perform_async(run.id)
      end
    end
  rescue ActiveRecord::ActiveRecordError => e
    Sidekiq.logger.warn("startup_sweep skipped: #{e.class}")
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
