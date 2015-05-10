raise "Do not directly load this library." unless defined?(ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter)

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
        spec[:charset]   = column.charset.inspect if column.charset && column.charset != charset
        spec[:collation] = column.collation.inspect if column.collation && column.collation != collation
        spec
      end

      def migration_keys
        super + [:charset, :collation]
      end

      def utf8mb4_supported?
        if @utf8mb4_supported.nil?
          @utf8mb4_supported = !select("show character set like 'utf8mb4'").empty?
        else
          @utf8mb4_supported
        end
      end

      def charset_collation(charset, collation)
        [charset, collation].map { |name|
          case name
          when nil
            nil
          when /\A(utf8mb4(_\w*)?)\z/
            if utf8mb4_supported?
              $1
            else
              "utf8#{$2}"
            end
          else
            name.to_s
          end
        }
      end

      def create_database(name, options = {})
        # utf8mb4 is used in column definitions; use utf8 for
        # databases.
        [:charset, :collation].each { |key|
          case options[key]
          when /\A(utf8mb4(_\w*)?)\z/
            options = options.merge(key => "utf8#{$2}")
          end
        }
        super(name, options)
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
          charset, collation = @conn.charset_collation(options[:charset], options[:collation])

          if charset
            sql << " CHARACTER SET #{charset}"
          end

          if collation
            sql << " COLLATE #{collation}"
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
end
