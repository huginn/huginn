module Dotenv
  EXPORT_COMMAND = "export ".freeze
  # Class for creating a template from a env file
  class EnvTemplate
    def initialize(env_file)
      @env_file = env_file
    end

    def create_template
      File.open(@env_file, "r") do |env_file|
        File.open("#{@env_file}.template", "w") do |env_template|
          env_file.each do |line|
            if is_comment?(line)
              env_template.puts line
            elsif (var = var_defined?(line))
              if line.match(EXPORT_COMMAND)
                env_template.puts "export #{var}=#{var}"
              else
                env_template.puts "#{var}=#{var}"
              end
            elsif line_blank?(line)
              env_template.puts
            end
          end
        end
      end
    end

    private

    def is_comment?(line)
      line.strip.start_with?("#")
    end

    def var_defined?(line)
      match = Dotenv::Parser::LINE.match(line)
      match && match[:key]
    end

    def line_blank?(line)
      line.strip.length.zero?
    end
  end
end
