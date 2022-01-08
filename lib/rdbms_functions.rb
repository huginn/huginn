module RdbmsFunctions
  def rdbms_date_add(source, unit, amount)
    adapter_type = ActiveRecord::Base.connection.adapter_name.downcase.to_sym
    case adapter_type
      when :mysql, :mysql2
        "DATE_ADD(`#{source}`, INTERVAL #{amount} #{unit})"
      when :postgresql
        "(#{source} + INTERVAL '#{amount} #{unit}')"
      else
        raise NotImplementedError, "Unknown adapter type '#{adapter_type}'"
    end
  end
end
