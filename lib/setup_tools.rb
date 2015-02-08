require 'open3'
require 'io/console'
require 'securerandom'
require 'shellwords'
require 'active_support/core_ext/object/blank'

module SetupTools
  def capture(cmd, opts = {})
    if opts.delete(:no_stderr)
      o, s = Open3.capture2(cmd, opts)
    else
      o, s = Open3.capture2e(cmd, opts)
    end
    o.strip
  end

  def grab_config_with_cmd!(cmd, opts = {})
    config_data = capture(cmd, opts)
    $config = {}
    if config_data !~ /has no config vars/
      config_data.split("\n").map do |line|
        next if line =~ /^\s*(#|$)/ # skip comments and empty lines
        first_equal_sign = line.index('=')
        raise "Invalid line found in config: #{line}" unless first_equal_sign
        $config[line.slice(0, first_equal_sign)] = line.slice(first_equal_sign + 1, line.length)
      end
    end
  end

  def print_config
    if $config.length > 0
      puts
      puts "Your current config:"
      $config.each do |key, value|
        puts '  ' + key + ' ' * (25 - [key.length, 25].min) + '= ' + value
      end
    end
  end

  def set_defaults!
    unless $config['APP_SECRET_TOKEN']
      puts "Setting up APP_SECRET_TOKEN..."
      set_value 'APP_SECRET_TOKEN', SecureRandom.hex(64)
    end
    set_value 'RAILS_ENV', "production"
    set_value 'FORCE_SSL', "true"
    set_value 'USE_GRAPHVIZ_DOT', 'dot'
    unless $config['INVITATION_CODE']
      puts "You need to set an invitation code for your Huginn instance.  If you plan to share this instance, you will"
      puts "tell this code to anyone who you'd like to invite.  If you won't share it, then just set this to something"
      puts "that people will not guess."

      invitation_code = nag("What code would you like to use?")
      set_value 'INVITATION_CODE', invitation_code
    end
  end

  def confirm_app_name(app_name)
    unless yes?("Your app name is '#{app_name}'.  Is this correct?", default: :yes)
      puts "Well, then I'm not sure what to do here, sorry."
      exit 1
    end
  end

  # expects set_env(key, value) to be defined.
  def set_value(key, value, options = {})
    if $config[key].nil? || $config[key] == '' || ($config[key] != value && options[:force] != false)
      puts "Setting #{key} to #{value}" unless options[:silent]
      puts set_env(key, value)
      $config[key] = value
    end
  end

  def ask(question, opts = {})
    print question + " "
    STDOUT.flush
    (opts[:noecho] ? STDIN.noecho(&:gets) : gets).strip
  end

  def nag(question, opts = {})
    answer = ''
    while answer.length == 0
      answer = ask(question, opts)
    end
    answer
  end

  def yes?(question, opts = {})
    if opts[:default].to_s[0...1] == "y"
      (ask(question + " (Y/n)").presence || "yes") =~ /^y/i
    else
      ask(question + " (y/n)") =~ /^y/i
    end
  end
end