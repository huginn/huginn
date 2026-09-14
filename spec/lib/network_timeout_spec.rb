require "rails_helper"

network_timeout_env_keys = %w[OUTBOUND_NETWORK_OPEN_TIMEOUT OUTBOUND_NETWORK_TIMEOUT].freeze

describe NetworkTimeout do
  around do |example|
    original_values = network_timeout_env_keys.to_h { |key| [key, ENV[key]] }
    example.run
  ensure
    original_values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    described_class.configure!
  end

  before do
    allow(Delayed::Worker).to receive(:max_run_time).and_return(120)
    network_timeout_env_keys.each { |key| ENV.delete(key) }
  end

  describe ".timeout" do
    it "defaults to 60 seconds" do
      expect(described_class.timeout).to eq(60)
    end

    it "honors the configured timeout" do
      ENV["OUTBOUND_NETWORK_TIMEOUT"] = "45.5"

      expect(described_class.timeout).to eq(45.5)
    end

    it "caps a request-specific timeout" do
      ENV["OUTBOUND_NETWORK_TIMEOUT"] = "45"

      expect(described_class.timeout(90)).to eq(45)
    end

    it "stays below the delayed job runtime" do
      ENV["OUTBOUND_NETWORK_TIMEOUT"] = "300"

      expect(described_class.timeout).to eq(118)
    end

    it "rejects non-positive values" do
      ENV["OUTBOUND_NETWORK_TIMEOUT"] = "0"

      expect { described_class.timeout }.to raise_error(ArgumentError, /must be a positive/)
    end
  end

  describe ".open_timeout" do
    it "defaults to 10 seconds" do
      expect(described_class.open_timeout).to eq(10)
    end

    it "does not exceed the request timeout" do
      ENV["OUTBOUND_NETWORK_TIMEOUT"] = "5"
      ENV["OUTBOUND_NETWORK_OPEN_TIMEOUT"] = "30"

      expect(described_class.open_timeout).to eq(5)
    end
  end

  describe ".configure_net_http" do
    it "sets every supported I/O timeout" do
      http = instance_double(Net::HTTP)
      allow(http).to receive(:respond_to?).with(:write_timeout=).and_return(true)
      expect(http).to receive(:open_timeout=).with(10)
      expect(http).to receive(:read_timeout=).with(60)
      expect(http).to receive(:write_timeout=).with(60)

      expect(described_class.configure_net_http(http)).to equal(http)
    end
  end

  describe ".within" do
    it "interrupts an operation at the common timeout" do
      ENV["OUTBOUND_NETWORK_TIMEOUT"] = "0.01"

      expect { described_class.within { sleep } }.to raise_error(Timeout::Error)
    end
  end

  describe ".configure!" do
    it "sets defaults for the shared HTTP clients" do
      ENV["OUTBOUND_NETWORK_OPEN_TIMEOUT"] = "3"
      ENV["OUTBOUND_NETWORK_TIMEOUT"] = "12"

      described_class.configure!

      request_options = Faraday.default_connection_options.request
      expect(request_options.open_timeout).to eq(3)
      expect(request_options.timeout).to eq(12)
      expect(request_options.read_timeout).to eq(12)
      expect(request_options.write_timeout).to eq(12)
      expect(Typhoeus::Config.connecttimeout).to eq(3)
      expect(Typhoeus::Config.timeout).to eq(12)
      expect(HTTParty::Basement.default_options).to include(
        open_timeout: 3,
        read_timeout: 12,
        write_timeout: 12,
        timeout: 12
      )
      expect(Aws.config).to include(http_open_timeout: 3, http_read_timeout: 12)
      expect(Google::Apis::ClientOptions.default).to have_attributes(
        open_timeout_sec: 3,
        read_timeout_sec: 12,
        send_timeout_sec: 12
      )
      expect(Twilio.http_client.timeout).to eq(12)
      expect(ActionMailer::Base.smtp_settings).to include(open_timeout: 3, read_timeout: 12)
    end
  end
end
