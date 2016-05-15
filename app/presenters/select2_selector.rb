# Encapsulates the logic for a select2-based HTML selector.
class Select2Selector < Selector
  # url_prefix --- The url prefix to set within the select2 element.
  def initialize(url_prefix:, **args)
    super(args)
    @url_prefix = url_prefix
  end

  protected

  def html_options
    {
      multiple: true,
      size: 5,
      class: 'select2-linked-tags form-control',
      data: {url_prefix: url_prefix},
    }
  end

  private

  attr_reader :url_prefix

  def filtered_data
    data.select(&filter)
  end
end
