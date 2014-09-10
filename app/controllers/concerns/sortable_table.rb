require 'active_support/concern'

module SortableTable
  extend ActiveSupport::Concern

  included do
    helper SortableTableHelper
  end

  protected

  def table_sort
    raise("You must call set_table_sort in any action using table_sort.") unless @table_sort_info.present?
    @table_sort_info[:order]
  end

  def set_table_sort(sort_options)
    valid_sorts = sort_options[:sorts] || raise("You must specify :sorts as an array of valid sort attributes.")
    default = sort_options[:default] || { valid_sorts.first.to_sym => :desc }

    if params[:sort].present?
      attribute, direction = params[:sort].downcase.split('.')
      unless valid_sorts.include?(attribute)
        attribute, direction = default.to_a.first
      end
    else
      attribute, direction = default.to_a.first
    end

    direction = direction.to_s == 'desc' ? 'desc' : 'asc'

    @table_sort_info = {
      order: { attribute.to_sym => direction.to_sym },
      attribute: attribute,
      direction: direction
    }
  end

  module SortableTableHelper
    def sortable_column(attribute, name = attribute.humanize, default_direction = 'desc')
      selected = @table_sort_info[:attribute].to_s == attribute
      if selected
        direction = @table_sort_info[:direction]
        new_direction = direction.to_s == 'desc' ? 'asc' : 'desc'
        classes = "selected #{direction}"
      else
        classes = ''
        new_direction = default_direction
      end
      link_to(name, url_for(sort: "#{attribute}.#{new_direction}"), class: classes)
    end
  end
end