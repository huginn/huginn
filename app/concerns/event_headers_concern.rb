# frozen_string_literal: true

module EventHeadersConcern
  private

  def validate_event_headers_options!
    event_headers_payload({})
  rescue ArgumentError => e
    errors.add(:base, e.message)
  rescue Liquid::Error => e
    errors.add(:base, "has an error with Liquid templating: #{e.message}")
  end

  def event_headers_normalizer
    case interpolated['event_headers_style']
    when nil, '', 'capitalized'
      ->name { name.gsub(/[^-]+/, &:capitalize) }
    when 'downcased'
      :downcase.to_proc
    when 'snakecased', nil
      ->name { name.tr('A-Z-', 'a-z_') }
    when 'raw'
      :itself.to_proc
    else
      raise ArgumentError, "if provided, event_headers_style must be 'capitalized', 'downcased', 'snakecased' or 'raw'"
    end
  end

  def event_headers_key
    case key = interpolated['event_headers_key']
    when nil, String
      key.presence
    else
      raise ArgumentError, "if provided, event_headers_key must be a string"
    end
  end

  def event_headers_payload(headers)
    key = event_headers_key or return {}

    normalize = event_headers_normalizer

    hash = headers.transform_keys(&normalize)

    names =
      case event_headers = interpolated['event_headers']
      when Array
        event_headers.map(&:to_s)
      when String
        event_headers.split(',')
      when nil
        nil
      else
        raise ArgumentError, "if provided, event_headers must be an array of strings or a comma separated string"
      end

    {
      key => names ? hash.slice(*names.map(&normalize)) : hash
    }
  end
end
