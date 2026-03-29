require_relative "../gemfile_helper"
require "bundler"
require "pathname"

namespace :vendor do
  desc "Update the vendored dotenv gem from RubyGems"
  task :update_dotenv, [:version] do |_task, args|
    require "fileutils"

    root = Pathname.new(__dir__).join("../..").expand_path
    vendor_root = root.join("vendor/gems")
    tmp_root = root.join(".tmp/vendor")
    tmp_root.mkpath

    version = args[:version] || ENV["VERSION"] || locked_dotenv_version(root)
    gem_file = tmp_root.join("dotenv-#{version}.gem")
    target_dir = vendor_root.join("dotenv-#{version}")

    Dir.chdir(tmp_root) do
      run_unbundled Gem.ruby, "-S", "gem", "fetch", "dotenv",
        "--version", version,
        "--clear-sources",
        "--source", "https://rubygems.org"
    end

    rm_rf target_dir
    run_unbundled Gem.ruby, "-S", "gem", "unpack", gem_file.to_s, "--target", vendor_root.to_s
    run_unbundled Gem.ruby, "-S", "gem", "specification", gem_file.to_s, "--ruby", out: target_dir.join("dotenv.gemspec").to_s
    run_unbundled Gem.ruby, "-S", "bundle", "lock", "--update", "dotenv"

    vendor_root.glob("dotenv-*").each do |path|
      next if path == target_dir

      rm_rf path
    end

    rm_f gem_file

    puts "Vendored dotenv #{version} to #{target_dir.relative_path_from(root)}"
  end

  def locked_dotenv_version(root)
    lockfile = Bundler::LockfileParser.new(root.join("Gemfile.lock").read)
    spec = lockfile.specs.find { |candidate| candidate.name == "dotenv" }
    raise "Could not find dotenv in Gemfile.lock" unless spec

    spec.version.to_s
  end

  def run_unbundled(...)
    Bundler.with_unbundled_env do
      sh(...)
    end
  end
end
