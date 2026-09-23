require "open3"
require "tmpdir"

describe "the bundled MySQL upgrade guard" do
  around do |example|
    Dir.mktmpdir("huginn-mysql-upgrade") do |directory|
      @datadir = directory
      example.run
    end
  end

  def run_guard
    Open3.capture2e("bash", File.expand_path("../../docker/multi-process/scripts/upgrade-mysql", __dir__), @datadir)
  end

  def write_redo_log(version)
    File.binwrite(File.join(@datadir, "ib_logfile0"), "\0" * 16 + version.ljust(32, "\0"))
  end

  it "refuses MySQL 5.7 without modifying its data" do
    write_redo_log("MySQL5.7.44")
    path = File.join(@datadir, "ib_logfile0")
    original = File.binread(path)

    output, status = run_guard

    expect(status.exitstatus).to eq(1)
    expect(output).to include("intermediate upgrade to MySQL 8.0")
    expect(Dir.children(@datadir)).to eq(["ib_logfile0"])
    expect(File.binread(path)).to eq(original)
  end

  it "allows MySQL 8.0 data to reach the server upgrade process" do
    write_redo_log("MySQL8.0.30")

    output, status = run_guard

    expect(status).to be_success
    expect(output).to be_empty
  end

  it "allows a new data directory without creating files" do
    output, status = run_guard

    expect(status).to be_success
    expect(output).to be_empty
    expect(Dir.children(@datadir)).to be_empty
  end
end
