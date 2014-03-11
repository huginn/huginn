module RDBMSFunctions
  def rdbms_date_add(source, unit, amount)
    adapter_type = connection.adapter_name.downcase.to_sym
    case adapter_type
      when :mysql
        "DATE_ADD(`#{source}`, INTERVAL #{unit} #{AMOUNT})"
      when :postgresql    
        "(#{source} + INTERVAL '#{amount} #{unit}')"
      else
        raise NotImplementedError, "Unknown adapter type '#{adapter_type}'"
    end
  end
end
