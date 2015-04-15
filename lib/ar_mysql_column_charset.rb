# Module#prepend support for Ruby 1.9
require 'prepend' unless Module.method_defined?(:prepend)

require 'active_support'

ActiveSupport.on_load :active_record do
  class << ActiveRecord::Base
    def establish_connection(spec = nil)
      super.tap { |ret|
        if /mysql/i === connection.adapter_name
          require 'ar_mysql_column_charset/main'
        end
      }
    end
  end
end
