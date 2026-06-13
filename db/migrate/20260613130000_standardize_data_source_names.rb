# D-191: standardize collection names (data_sources.name). Since Wydawca (organization) is now its own picker
# field, the collection name must not repeat the publisher - drop the publisher prefix, keep the product/brand,
# one acronym in parens where standard. Runs on deploy via db:prepare; seeds updated to match (create-only blocks,
# so this is not reverted by re-seeding an existing DB).
class StandardizeDataSourceNames < ActiveRecord::Migration[8.1]
  NAMES = {
    "wb_wdi"          => "World Development Indicators (WDI)",
    "wb_wgi"          => "Worldwide Governance Indicators (WGI)",
    "wb_gender"       => "Gender Statistics",
    "wb_poverty"      => "Poverty & Equity",
    "wb_findex"       => "Global Findex Database",
    "wb_edstats"      => "Education Statistics (EdStats)",
    "wb_hnp"          => "Health, Nutrition & Population",
    "eurostat_social" => "Social & economic indicators",
    "eurostat"        => "European statistics",
    "oecd"            => "How's Life? Well-Being & PISA",
    "oecd_health"     => "Health & Education statistics",
    "owid_co2"        => "CO₂ & Greenhouse-Gas Emissions",
    "owid_energy"     => "Energy",
    "owid_health"     => "Health, Democracy & Food",
    "undp_hdi"        => "Human Development Report",
    "unesco_uis"      => "Education statistics",
    "faostat"         => "FAOSTAT",
    "ilostat"         => "ILOSTAT",
    "unctadstat"      => "UNCTADstat",
    "un_wpp"          => "World Population Prospects 2024",
    "idb_lac"         => "Latin Macro Watch",
    "mo_ibrahim_iiag" => "Index of African Governance (IIAG)",
    "sedlac"          => "SEDLAC",
    "rieti"           => "Industry-Specific Exchange Rates",
    "polity5"         => "Polity5",
    "vdem"            => "Varieties of Democracy (V-Dem)",
    "wid"             => "World Inequality Database (WID)",
    "maddison"        => "Maddison Project Database",
    "wjp_rol"         => "Rule of Law Index",
    "bti"             => "Transformation Index (BTI)",
    "mpi"             => "Multidimensional Poverty Index (MPI)",
    "niti_aayog"      => "SDG India Index",
    "aseanstats"      => "ASEANstats",
    "afristat_uneca"  => "ECAStats",
    "cis_stat"        => "National statistics",
    "gcc_stat"        => "National statistics",
    "ibge_sidra"      => "National statistics (SIDRA)",
    "inegi_mexico"    => "National statistics",
    "cbs_israel"      => "National statistics",
    "pbs_pakistan"    => "National statistics"
  }.freeze

  def up
    NAMES.each do |code, name|
      execute "UPDATE data_sources SET name = #{connection.quote(name)} WHERE code = #{connection.quote(code)}"
    end
  end

  def down
    # Cosmetic labels only; no rollback.
  end
end
