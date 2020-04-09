module Dotenv
  # Class for creating a template from a env file
  class EnvTemplate
    def initialize(env_file)
      @env_file = env_file
    end

    def create_template
      File.open(@env_file, "r") do |env_file|
        File.open("#{@env_file}.template", "w") do |env_template|
          env_file.each do |line|
            variable = line.split("=").first
            env_template.puts "#{variable}=#{variable}"
          end
        end
      end
    end
  end
end
