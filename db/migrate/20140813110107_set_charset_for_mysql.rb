class SetCharsetForMysql < ActiveRecord::Migration[4.2]
  def all_models
    @all_models ||= [
      Agent,
      AgentLog,
      Event,
      Link,
      Scenario,
      ScenarioMembership,
      User,
      UserCredential,
      Delayed::Job,
    ]
  end

  def change
    # This is migration is for MySQL only.
    return unless mysql?

    reversible do |dir|
      dir.up do
        all_models.each { |model|
          table_name = model.table_name

          next unless connection.table_exists? table_name

          model.columns.each { |column|
            name = column.name
            type = column.type
            limit = column.limit
            options = {
              limit: limit,
              null: column.null,
              default: column.default,
            }

            case type
            when :string, :text
              options.update(charset: 'utf8', collation: 'utf8_unicode_ci')
              case name
              when 'username'
                options.update(limit: 767 / 4, charset: 'utf8mb4', collation: 'utf8mb4_unicode_ci')
              when 'message', 'options', 'name', 'memory',
                   'handler', 'last_error', 'payload', 'description'
                options.update(charset: 'utf8mb4', collation: 'utf8mb4_bin')
              when 'type', 'schedule', 'mode', 'email',
                   'invitation_code', 'reset_password_token'
                options.update(collation: 'utf8_bin')
              when 'guid', 'encrypted_password'
                options.update(charset: 'ascii', collation: 'ascii_bin')
              end
            else
              next
            end

            change_column table_name, name, type, options
          }

          execute 'ALTER TABLE %s CHARACTER SET utf8 COLLATE utf8_unicode_ci' % table_name
        }

        execute 'ALTER DATABASE `%s` CHARACTER SET utf8 COLLATE utf8_unicode_ci' % connection.current_database
      end

      dir.down do
        # Do nada; no use to go back
      end
    end
  end

  def mysql?
    ActiveRecord::Base.connection.adapter_name =~ /mysql/i
  end
end
