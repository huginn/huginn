require "dotenv"
require "dotenv/version"
require "dotenv/template"
require "optparse"

module Dotenv
  # The CLI is a class responsible of handling all the command line interface
  # logic.
  class CLI
    attr_reader :argv, :filenames

    def initialize(argv = [])
      @argv = argv.dup
      @filenames = []
    end

    def run
      parse_argv!(@argv)

      begin
        Dotenv.load!(*@filenames)
      rescue Errno::ENOENT => e
        abort e.message
      else
        exec(*@argv) unless @argv.empty?
      end
    end

    private

    def parse_argv!(argv)
      parser = create_option_parser
      add_options(parser)
      parser.order!(argv)

      @filenames
    end

    def add_options(parser)
      add_files_option(parser)
      add_help_option(parser)
      add_version_option(parser)
      add_template_option(parser)
    end

    def add_files_option(parser)
      parser.on("-f FILES", Array, "List of env files to parse") do |list|
        @filenames = list
      end
    end

    def add_help_option(parser)
      parser.on("-h", "--help", "Display help") do
        puts parser
        exit
      end
    end

    def add_version_option(parser)
      parser.on("-v", "--version", "Show version") do
        puts "dotenv #{Dotenv::VERSION}"
        exit
      end
    end

    def add_template_option(parser)
      parser.on("-t", "--template=FILE", "Create a template env file") do |file|
        template = Dotenv::EnvTemplate.new(file)
        template.create_template
      end
    end

    def create_option_parser
      OptionParser.new do |parser|
        parser.banner = "Usage: dotenv [options]"
        parser.separator ""
      end
    end
  end
end
