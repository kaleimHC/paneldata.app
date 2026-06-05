# RUN CONFIGURATION. Response defaults to GDP per capita (constant 2015 US$), overridable.
# Predictor = chosen via the shared IndicatorPickerComponent.
# The form is driven by the `pvar` Stimulus controller (POST /analyses -> poll -> render).
class RunConfigComponent < ViewComponent::Base
  # Single sources of truth, re-exposed for this component's template.
  BOOTSTRAP     = AnalysisRun::BOOTSTRAP
  RESPONSE_CODE = AnalysisRun::RESPONSE_CODE

  # Featured predictor default. EFW removed (owner fiat, informed) -> Rule of Law (owidh_rule_of_law:
  # CC-BY, 1789-, 174 countries, loggable) as the institutional->growth predictor for the featured Goes (2016) demo.
  def default_predictor = "owidh_rule_of_law"
end
