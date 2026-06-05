# Page chrome: top bar + sidebar (static desktop / drawer mobile) + main (block content) + footer.
# The block passed to `render` becomes the main column. selected_code seeds the sidebar data-selection.
class LayoutChromeComponent < ViewComponent::Base
  def initialize(selected_code: "NY.GDP.PCAP.KD", initial_view: "explore", result_mode: false)
    @selected_code = selected_code
    @initial_view = initial_view
    @result_mode = result_mode
  end
  attr_reader :selected_code, :initial_view, :result_mode
end
