# Indicator browsing taxonomy: the 4 axes the pickers navigate by. Two of them already live in the
# data (Wydawca = data_sources.organization, Kolekcja = data_sources.name); this module supplies the two that
# need curated mappings:
#   - Dziedzina (theme): indicators.dimension is dirty/granular (66 values, synonyms) -> ~11 clean groups.
#   - Pokrycie/Region: derived per data_source.code; unlisted sources are Global (the default that de-clutters).
# Keys are stable; human labels are i18n'd (indicators.dziedzina.* / indicators.scope.* / indicators.region.*).
module IndicatorTaxonomy
  # raw indicators.dimension (downcased) -> dziedzina key. Anything unmapped (incl. nil) -> "other".
  DZIEDZINA = {
    # Gospodarka i finanse
    "economic" => "economy", "economy" => "economy", "national accounts" => "economy",
    "prices" => "economy", "market economy" => "economy", "finance" => "economy",
    "financial inclusion" => "economy", "industry" => "economy", "agriculture" => "economy",
    # Handel
    "trade" => "trade", "trade and exchange rates" => "trade", "trade and terms of trade" => "trade",
    # Instytucje i rzadzenie
    "governance" => "governance", "democracy" => "governance", "rule_of_law" => "governance",
    "institutional" => "governance", "institutions" => "governance", "freedoms" => "governance",
    "rights" => "governance", "press freedom" => "governance", "peace" => "governance",
    "transformation status" => "governance",
    # Zdrowie
    "health" => "health", "health expenditure" => "health", "health system" => "health",
    "immunization" => "health", "mortality" => "health", "infectious disease" => "health",
    "risk factors" => "health", "nutrition" => "health", "food" => "health",
    # Edukacja i nauka
    "education" => "education", "primary education" => "education", "secondary education" => "education",
    "tertiary education" => "education", "pre-primary education" => "education",
    "learning outcomes" => "education", "literacy" => "education", "teaching quality" => "education",
    "education system" => "education", "education expenditure" => "education",
    "human capital" => "education", "science" => "education",
    # Praca
    "labour" => "labour", "labor" => "labour",
    # Demografia
    "demographic" => "demography", "demography" => "demography", "demographics" => "demography",
    "population" => "demography",
    # Srodowisko i energia
    "environment" => "environment", "energy" => "environment", "water & sanitation" => "environment",
    # Rozwoj i ubostwo
    "development" => "development", "sustainable development" => "development", "poverty" => "development",
    "inequality" => "development", "wellbeing" => "development", "welfare" => "development",
    "social policy" => "development",
    # Plec
    "gender" => "gender",
    # Infrastruktura i innowacje
    "infrastructure" => "infrastructure", "digital" => "infrastructure", "digital society" => "infrastructure",
    "innovation" => "infrastructure", "tourism" => "infrastructure"
  }.freeze

  DZIEDZINA_KEYS = (DZIEDZINA.values.uniq + ["other"]).freeze

  # data_source.code -> [scope, region_key]. Scope drives Pokrycie (global/regional/national); region_key labels
  # the conditional second field. Coverage thresholds that informed this: 1 country = national, ~6-54 = regional,
  # ~80+ = global (clean gap between 54 and 88). Any source not listed here is Global with no region.
  SOURCE_SCOPE = {
    "ibge_sidra"      => %w[national brazil],
    "niti_aayog"      => %w[national india],
    "pbs_pakistan"    => %w[national pakistan],
    "cbs_israel"      => %w[national israel],
    "inegi_mexico"    => %w[national mexico],
    "gcc_stat"        => %w[regional gulf],
    "aseanstats"      => %w[regional asean],
    "cis_stat"        => %w[regional cis],
    "sedlac"          => %w[regional latam],
    "idb_lac"         => %w[regional latam],
    "rieti"           => %w[regional asia],
    "eurostat"        => %w[regional europe],
    "eurostat_social" => %w[regional europe],
    "oecd"            => %w[regional oecd],
    "oecd_health"     => %w[regional oecd],
    "afristat_uneca"  => %w[regional africa],
    "mo_ibrahim_iiag" => %w[regional africa],
    # Classified by served-country count (1 = national, 6-54 = regional, 80+ = global).
    "ecb_sdw"         => %w[regional europe],
    "adb_kidb"        => %w[regional asia],
    "gms_statistics"  => %w[regional mekong],
    "insee_bdm"       => %w[national france],
    "ssb_norway"      => %w[national norway],
    "scb_sweden"      => %w[national sweden],
    "bahrain_oda"     => %w[national bahrain],
    "qatar_psa"       => %w[national qatar],
    "morocco_hcp"     => %w[national morocco],
    "ghana_godi"      => %w[national ghana],
    "guatemala_ine"   => %w[national guatemala],
    "singstat"        => %w[national singapore],
    "opendosm"        => %w[national malaysia],
    "bcb_sgs"         => %w[national brazil],
    "ipeadata"        => %w[national brazil],
    "bps_indonesia"   => %w[national indonesia]
  }.freeze

  REGIONAL_KEYS = SOURCE_SCOPE.values.select { |s, _| s == "regional" }.map(&:last).uniq.freeze
  NATIONAL_KEYS = SOURCE_SCOPE.values.select { |s, _| s == "national" }.map(&:last).uniq.freeze

  def self.dziedzina(dimension)
    DZIEDZINA[dimension.to_s.downcase.strip] || "other"
  end

  def self.scope(ds_code)  = SOURCE_SCOPE.dig(ds_code, 0) || "global"
  def self.region(ds_code) = SOURCE_SCOPE.dig(ds_code, 1)

  # Curated short publisher label, used by the collection display as a fallback when the full publisher does
  # not fit and there is no parenthetical acronym to extract - e.g. the acronym lives at the START of the org name
  # ("GCC Statistical Center" -> GCC) or is a brand not in the org string ("Global Change Data Lab ..." -> OWID).
  # Only sources the algorithm misses need an entry here; FAO/ILO/UNCTAD/UIS/IDB/IBGE/INEGI/PBS/UNECA/GGDC already
  # resolve from their parenthetical acronym, ASEAN/Eurostat from the full name.
  PUBLISHER_SHORT = {
    "wb_wdi" => "World Bank", "wb_wgi" => "World Bank", "wb_gender" => "World Bank", "wb_poverty" => "World Bank",
    "wb_findex" => "World Bank", "wb_edstats" => "World Bank", "wb_hnp" => "World Bank",
    "owid_co2" => "OWID", "owid_energy" => "OWID", "owid_health" => "OWID",
    "oecd" => "OECD", "oecd_health" => "OECD",
    "undp_hdi" => "UNDP", "wjp_rol" => "WJP", "niti_aayog" => "NITI Aayog", "cbs_israel" => "CBS Israel",
    "gcc_stat" => "GCC", "cis_stat" => "CIS-Stat", "vdem" => "V-Dem", "epi_yale" => "Yale EPI",
    "mo_ibrahim_iiag" => "Mo Ibrahim", "wid" => "WID", "sedlac" => "SEDLAC", "rieti" => "RIETI", "bti" => "Bertelsmann"
  }.freeze

  def self.publisher_short(ds_code) = PUBLISHER_SHORT[ds_code]
end
