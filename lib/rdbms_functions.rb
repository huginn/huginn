module RdbmsFunctions
  def rdbms_date_add(source, unit, amount)
    "(#{source} + INTERVAL '#{amount} #{unit}')"
  end
end
