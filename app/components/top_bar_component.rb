# Top chrome (a4institutional): navy brand bar + inert nav + FUNCTIONAL view-tabs (in-page, NO routes).
# Labels are i18n keys - resolved via t in the template, not hardcoded here.
class TopBarComponent < ViewComponent::Base
  NAV_KEYS = %w[methodology].freeze
  # View tabs (explore/analysis) now live in SidebarComponent (left rail), not here.
end
