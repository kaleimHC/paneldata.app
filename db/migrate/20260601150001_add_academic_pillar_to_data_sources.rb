# WAVE 3: data_sources.pillar taxonomy needs an academic category - V-Dem (and future
# Polity5/Maddison/PWT/QoG) are academic consortia, not geopolitical pillars. Additive enum extend.
class AddAcademicPillarToDataSources < ActiveRecord::Migration[8.1]
  OLD = %w[un multilateral non_anglo regional composite western conflict national].freeze
  NEW = (OLD + %w[academic_consortium]).freeze

  def up
    remove_check_constraint :data_sources, name: "data_sources_pillar_check"
    add_check_constraint :data_sources,
      "pillar IS NULL OR pillar IN (#{NEW.map { |p| "'#{p}'" }.join(',')})",
      name: "data_sources_pillar_check"
  end

  def down
    remove_check_constraint :data_sources, name: "data_sources_pillar_check"
    add_check_constraint :data_sources,
      "pillar IS NULL OR pillar IN (#{OLD.map { |p| "'#{p}'" }.join(',')})",
      name: "data_sources_pillar_check"
  end
end
