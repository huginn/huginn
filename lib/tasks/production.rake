def failed; "[ \033[31mFAIL\033[0m ]"; end
def ok;     "[  \033[32mOK\033[0m  ]"; end

def run_as_root
  return true if ENV['USER'] == 'root'
  puts "#{failed} Please run this command as root or with sudo\n\n"
  exit -1
end

def runit_installed
  return true unless `which sv` && $?.to_i != 0
  puts "#{failed} Please install runit: \n\nsudo apt-get install runit\n\n"
  exit -1
end

def remove_upstart_config
  return true unless File.exists?('/etc/init/huginn.conf')
  puts "#{failed} Please stop huginn and remove the huginn upstart init scripts:\n\n"
  puts "sudo stop huginn"
  puts "sudo rm /etc/init/huginn*\n\n"
  exit -1
end

namespace :production do
  task :check do |t|
    remove_upstart_config
    runit_installed
    puts "#{ok} Everything is fine" if t.application.top_level_tasks.include? 'production:check'
  end

  task :stop => :check do
    puts "Stopping huginn ..."
    run_sv('stop')
  end

  task :start => :check do
    puts "Startig huginn ..."
    run_sv('start')
  end

  task :force_stop => :check do
    puts "Force stopping huginn ..."
    run_sv('force-stop')
  end

  task :status => :check do
    run_sv('status')
  end

  task :restart => :check do
    puts "Restarting huginn ..."
    run_sv('restart')
  end

  task :export => :check do
    run_as_root
    Rake::Task['production:stop'].execute
    puts "Exporting new services ..."
    run('rm -rf /etc/service/huginn*')
    run('foreman export runit -a huginn -l /home/huginn/huginn/log /etc/service')
    services = Dir.glob('/etc/service/huginn*')
    while services.length > 0
      services.each do |p|
        supervise = File.join(p, 'supervise')
        next if !Dir.exists?(supervise)
        run("chown -R huginn:huginn #{p}")
        services.delete(p)
      end
      sleep 0.1
    end
  end
end

def run_sv(command)
  Dir.glob('/etc/service/huginn*').each do |p|
    with_retries do
      run("sv #{command} #{File.basename(p)}")
    end
  end
end

def run(cmd, verbose=false)
  output = `#{cmd}`
  if $?.to_i != 0
    raise "'#{cmd}' exited with a non-zero return value: #{output}"
  end
  puts output if verbose && output.strip != ''
  output
end

def with_retries(&block)
  tries ||= 5
  output = block.call
rescue StandardError => e
  retry unless (tries -= 1).zero?
  raise e
else
  puts output
end
