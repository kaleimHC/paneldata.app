# D-191: the D-191 standardization shortened some collections to a bare brand/acronym (SEDLAC, FAOSTAT, ...) that
# is too terse to describe what it is. Expand those to a descriptive "Phrase (ACRONYM)" form. Runs on deploy via
# db:prepare; seeds updated to match (create-only blocks won't revert an existing DB).
class ExpandTerseCollectionNames < ActiveRecord::Migration[8.1]
  NAMES = {
    "sedlac"         => "Socio-Economic Database (SEDLAC)",
    "faostat"        => "Food & Agriculture (FAOSTAT)",
    "ilostat"        => "Labour Statistics (ILOSTAT)",
    "unctadstat"     => "Trade & Development (UNCTADstat)",
    "afristat_uneca" => "African Statistics (ECAStats)",
    "aseanstats"     => "ASEAN Statistics (ASEANstats)",
    "polity5"        => "Political Regime Data (Polity5)",
    "owid_energy"    => "Energy & Electricity"
  }.freeze

  def up
    NAMES.each do |code, name|
      execute "UPDATE data_sources SET name = #{connection.quote(name)} WHERE code = #{connection.quote(code)}"
    end
  end

  def down; end
end
