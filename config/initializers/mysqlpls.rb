# see https://github.com/rails/rails/issues/9855#issuecomment-28874587
# circumvents the default InnoDB limitation for index prefix bytes maximum when using proper 4byte UTF8 (utf8mb4)
# (for server-side workaround see http://dev.mysql.com/doc/refman/5.7/en/innodb-parameters.html#sysvar_innodb_large_prefix)
if ENV['ON_HEROKU'].nil?
  require 'active_record/connection_adapters/abstract_mysql_adapter'

  module ActiveRecord
    module ConnectionAdapters
      class AbstractMysqlAdapter
        NATIVE_DATABASE_TYPES[:string] = { :name => "varchar", :limit => 191 }
      end
    end
  end
end