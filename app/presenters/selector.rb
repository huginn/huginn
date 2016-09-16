# Encapsulates the logic for an HTML selector.
#
# Example:
#
#   # In the controller
#   data = (1..10).map { |i| Selector::Container.new("value #{i}", i) }
#   @selector = Selector.new(data: data, select_id: :my_attr, selected: 1, view: view_context)
#
#   # In the view
#   = f.select *selector
#
# When subclassing a Selector, there are two easy points for extension:
#
# * `#choices` should output data in the form expected by
#   `ActionView::Helpers::FormOptionsHelper#options_for_select`.
# * `#html_options` should output a hash that is sent as `html_options` in
#   `ActionView::Helpers::FormBuilder#select`.
# * `#options` should output a hash that is sent as `options` in
#   `ActionView::Helpers::FormBuilder#select`.
class Selector
  Container = Struct.new(:name, :id, :title)

  # data      --- The data to format for the selector options.
  # filter    --- A symbol id of a predicate to apply when filtering the data.
  # select_id --- The value to use for the "id" attr on the select element.
  # selected  --- The selected value in the selector.
  # view      --- The view context for generating the HTML.
  def initialize(data: [], filter: :present?, select_id:, selected:, view:)
    @data       = data
    @filter     = filter
    @select_id  = select_id
    @selected   = selected
    @view       = view
  end

  # Returns an array of items that can be passed to
  # `ActionView::Helpers::FormBuilder#select` with a splat.
  #
  # This is aliased to `#to_a` which allows you to splat the object.
  #
  # Example
  #
  #   <%= f.select *selector.as_select %>
  def as_select
    [
      select_id,
      view.options_for_select(choices, selected),
      options,
      html_options
    ]
  end
  alias_method :to_a, :as_select

  protected

  def choices
    filtered_data.map { |datum| [datum.name, datum.id] }
  end

  def html_options
    {class: 'form-control'}
  end

  def options
    {}
  end

  private

  attr_reader :data
  attr_reader :filter
  attr_reader :select_id
  attr_reader :selected
  attr_reader :view

  def filtered_data
    data.select(&filter)
  end
end
