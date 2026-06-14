# Drop the dead indicators.name_pl column (audit #23). Localized names live in config/locales/data/
# indicators.<locale>.yml read by Indicator#display_name (I18n.t, fallback to the English `name`); the
# name_pl column was written by 6 seeds but read by nothing (0 readers in app/lib/config). The PL values
# it held are redundant with the i18n YAML (~99.9% coverage), so this is pure cleanup, no data loss of record.
class RemoveNamePlFromIndicators < ActiveRecord::Migration[8.1]
  def up
    remove_column :indicators, :name_pl
  end

  def down
    add_column :indicators, :name_pl, :text
  end
end
