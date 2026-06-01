# D-045: typed observation values via PG ENUM (NOT a Rails string enum at DB level).
class CreateValueTypeEnum < ActiveRecord::Migration[8.1]
  def up
    create_enum :value_type_enum, %w[raw estimate percentile index rank categorical_code]
  end

  def down
    drop_enum :value_type_enum
  end
end
