# Left workspace rail (a4 data-selection + b4 workspace/run-history).
class SidebarComponent < ViewComponent::Base
  THEMES = %w[light mosiadz sepia grafit konsola nokturn kontrast].freeze # labels via t("themes.<value>"); 'light' shown as "Granatowy"
  VIEW_TABS = %w[explore analysis].freeze # in-page views (tab_controller); Results is a section inside analysis. label = t("tabs.<key>")
  DEFAULT_TAB = "explore"

  # initial_view + result_mode: a run opened from history navigates to /?run=<id>, so the active
  # tab + the "result-mode dims the analysis tab" state are rendered server-side (no post-paint flash).
  def initialize(selected_code: "NY.GDP.PCAP.KD", initial_view: DEFAULT_TAB, result_mode: false)
    @selected_code = selected_code
    @initial_view = initial_view
    @result_mode = result_mode
  end
  attr_reader :selected_code, :initial_view, :result_mode

  def themes = THEMES
  def view_tabs = VIEW_TABS

  # Which tab reads as active: explore when on explore; analysis only in config-mode (result-mode dims it - the
  # selected history card's border is the active marker instead, so selection stays unique).
  def tab_active?(key)
    key == "analysis" ? (initial_view == "analysis" && !result_mode) : (initial_view == key)
  end
end
