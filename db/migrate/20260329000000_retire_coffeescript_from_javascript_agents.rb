require "open3"

class RetireCoffeescriptFromJavascriptAgents < ActiveRecord::Migration[8.1]
  def up
    converted_credentials = {}

    ActiveRecord::Base.transaction do
      each_legacy_coffeescript_agent do |agent|
        credential_name = credential_referenced_by_code(agent.options["code"])
        if credential_name
          credential = UserCredential.find_by!(user_id: agent.user_id, credential_name:)
          credential_key = [credential.user_id, credential.credential_name]

          unless converted_credentials[credential_key]
            credential.update_columns(
              credential_value: compile_coffeescript(
                credential.credential_value,
                source: "credential #{credential.credential_name.inspect} for user #{credential.user_id}"
              ),
              mode: "java_script"
            ) or raise "Failed to update credential #{credential.credential_name.inspect} for user #{credential.user_id}"

            converted_credentials[credential_key] = true
          end
        else
          agent.options["code"] = compile_coffeescript(agent.options["code"], source: "agent #{agent.id}")
        end

        agent.options["language"] = "JavaScript"
        agent.update_columns(options: agent.options) or raise "Failed to update JavaScriptAgent #{agent.id}"
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "CoffeeScript agent code cannot be reconstructed automatically"
  end

  private

  def each_legacy_coffeescript_agent(&)
    case ActiveRecord::Base.connection.adapter_name
    when /mysql/i
      Agents::JavaScriptAgent.where("JSON_UNQUOTE(JSON_EXTRACT(options, '$.language')) = ?", "CoffeeScript").find_each(&)
    when /postgres/i
      Agents::JavaScriptAgent.where("(options::jsonb ->> 'language') = ?", "CoffeeScript").find_each(&)
    else
      Agents::JavaScriptAgent.find_each do |agent|
        yield agent if agent.options["language"] == "CoffeeScript"
      end
    end
  end

  def credential_referenced_by_code(code)
    stripped_code = code.to_s.strip
    return unless stripped_code.start_with?("credential:")

    stripped_code.delete_prefix("credential:")
  end

  def compile_coffeescript(source_code, source:)
    command = ["npx", "--yes", "-p", "coffeescript", "coffee", "--bare", "--stdio", "--print"]
    stdout, stderr, status = Open3.capture3(*command, stdin_data: source_code.to_s)

    return stdout if status.success?

    details = [stderr.presence, stdout.presence].compact.join("\n").strip
    raise "Failed to compile CoffeeScript from #{source}: #{details.presence || 'unknown error'}"
  rescue Errno::ENOENT => e
    raise "Failed to compile CoffeeScript from #{source}: #{e.message}"
  end

end
