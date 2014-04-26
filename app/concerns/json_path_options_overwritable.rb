module JsonPathOptionsOverwritable
  extend ActiveSupport::Concern

  private
  def merge_json_path_options(event)
    options.select { |k, v| options_with_path.include? k}.tap do |merged_options|
      options_with_path.each do |a|
        merged_options[a] = select_option(event, a)
      end
    end
  end

  def select_option(event, a)
    if options[a.to_s + '_path'].present?
      Utils.value_at(event.payload, options[a.to_s + '_path'])
    else
      options[a]
    end
  end
end