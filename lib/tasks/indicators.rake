namespace :indicators do
  desc "Backfill indicators.value_min/value_max from observations"
  task backfill_value_range: :environment do
    Indicator.backfill_value_range!
    n = Indicator.where("value_min <= 0").count
    puts "value range backfilled; #{n} indicators are non-loggable (value_min <= 0)"
  end
end
