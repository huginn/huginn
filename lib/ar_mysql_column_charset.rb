require 'active_record'

module ActiveRecord::ConnectionAdapters
  class ColumnDefinition
    module CharsetSupport
      attr_accessor :charset, :collation
    end

    prepend CharsetSupport
  end

  class TableDefinition
    module CharsetSupport
      def new_column_definition(name, type, options)
        column = super
        column.charset   = options[:charset]
        column.collation = options[:collation]
        column
      end
    end

    prepend CharsetSupport
  end

  class AbstractMysqlAdapter
    module CharsetSupport
      def prepare_column_options(column, types)
        spec = super
        conn = ActiveRecord::Base.connection
        spec[:charset]   = column.charset.inspect if column.charset && column.charset != conn.charset
        spec[:collation] = column.collation.inspect if column.collation && column.collation != conn.collation
        spec
      end

      def migration_keys
        super + [:charset, :collation]
      end
    end

    prepend CharsetSupport

    class SchemaCreation
      module CharsetSupport
        def column_options(o)
          column_options = super
          column_options[:charset]   = o.charset unless o.charset.nil?
          column_options[:collation] = o.collation unless o.collation.nil?
          column_options
        end

        def add_column_options!(sql, options)
          if options[:charset]
            sql << " CHARACTER SET #{options[:charset]}"
          end

          if options[:collation]
            sql << " COLLATE #{options[:collation]}"
          end

          super
        end
      end

      prepend CharsetSupport
    end

    class Column
      module CharsetSupport
        attr_reader :charset

        def initialize(*args)
          super
          @charset = @collation[/\A[^_]+/] unless @collation.nil?
        end
      end

      prepend CharsetSupport
    end
  end
end if Module.method_defined?(:prepend)  # ruby >=2.0
