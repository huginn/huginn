ActiveSupport.on_load :active_record do
  require 'ar_mysql_column_charset'
end
