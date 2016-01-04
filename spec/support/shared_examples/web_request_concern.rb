require 'rails_helper'

shared_examples_for WebRequestConcern do
  let(:agent) do
    _agent = described_class.new(:name => "some agent", :options => @valid_options || {})
    _agent.user = users(:jane)
    _agent
  end

  describe "validations" do
    it "should be valid" do
      expect(agent).to be_valid
    end

    it "should validate user_agent" do
      agent.options['user_agent'] = nil
      expect(agent).to be_valid

      agent.options['user_agent'] = ""
      expect(agent).to be_valid

      agent.options['user_agent'] = "foo"
      expect(agent).to be_valid

      agent.options['user_agent'] = ["foo"]
      expect(agent).not_to be_valid

      agent.options['user_agent'] = 1
      expect(agent).not_to be_valid
    end

    it "should validate headers" do
      agent.options['headers'] = "blah"
      expect(agent).not_to be_valid

      agent.options['headers'] = ""
      expect(agent).to be_valid

      agent.options['headers'] = {}
      expect(agent).to be_valid

      agent.options['headers'] = { 'foo' => 'bar' }
      expect(agent).to be_valid
    end

    it "should validate basic_auth" do
      agent.options['basic_auth'] = "foo:bar"
      expect(agent).to be_valid

      agent.options['basic_auth'] = ["foo", "bar"]
      expect(agent).to be_valid

      agent.options['basic_auth'] = ""
      expect(agent).to be_valid

      agent.options['basic_auth'] = nil
      expect(agent).to be_valid

      agent.options['basic_auth'] = "blah"
      expect(agent).not_to be_valid

      agent.options['basic_auth'] = ["blah"]
      expect(agent).not_to be_valid
    end

    it "should validate disable_ssl_verification" do
      agent.options['disable_ssl_verification'] = nil
      expect(agent).to be_valid

      agent.options['disable_ssl_verification'] = true
      expect(agent).to be_valid

      agent.options['disable_ssl_verification'] = false
      expect(agent).to be_valid

      agent.options['disable_ssl_verification'] = 'true'
      expect(agent).to be_valid

      agent.options['disable_ssl_verification'] = 'false'
      expect(agent).to be_valid

      agent.options['disable_ssl_verification'] = 'blah'
      expect(agent).not_to be_valid

      agent.options['disable_ssl_verification'] = 51
      expect(agent).not_to be_valid
    end
  end

  describe "User-Agent" do
    before do
      @default_http_user_agent = ENV['DEFAULT_HTTP_USER_AGENT']
      ENV['DEFAULT_HTTP_USER_AGENT'] = nil
    end

    after do
      ENV['DEFAULT_HTTP_USER_AGENT'] = @default_http_user_agent
    end

    it "should have the default value of Huginn" do
      expect(agent.user_agent).to eq('Huginn - https://github.com/cantino/huginn')
    end

    it "should be overridden by the environment variable if present" do
      ENV['DEFAULT_HTTP_USER_AGENT'] = 'Something'
      expect(agent.user_agent).to eq('Something')
    end

    it "should be overriden by the value in options if present" do
      agent.options['user_agent'] = 'Override'
      expect(agent.user_agent).to eq('Override')
    end
  end

  describe "#faraday" do
    it "should enable SSL verification by default" do
      expect(agent.faraday.ssl.verify).to eq(true)
    end

    it "should enable SSL verification when nil" do
      agent.options['disable_ssl_verification'] = nil
      expect(agent.faraday.ssl.verify).to eq(true)
    end

    it "should disable SSL verification if disable_ssl_verification option is 'true'" do
      agent.options['disable_ssl_verification'] = 'true'
      expect(agent.faraday.ssl.verify).to eq(false)
    end

    it "should disable SSL verification if disable_ssl_verification option is true" do
      agent.options['disable_ssl_verification'] = true
      expect(agent.faraday.ssl.verify).to eq(false)
    end

    it "should not disable SSL verification if disable_ssl_verification option is 'false'" do
      agent.options['disable_ssl_verification'] = 'false'
      expect(agent.faraday.ssl.verify).to eq(true)
    end

    it "should not disable SSL verification if disable_ssl_verification option is false" do
      agent.options['disable_ssl_verification'] = false
      expect(agent.faraday.ssl.verify).to eq(true)
    end

    it "should use faradays default params_encoder" do
      expect(agent.faraday.options.params_encoder).to eq(nil)
      agent.options['disable_url_encoding'] = 'false'
      expect(agent.faraday.options.params_encoder).to eq(nil)
      agent.options['disable_url_encoding'] = false
      expect(agent.faraday.options.params_encoder).to eq(nil)
    end

    it "should use WebRequestConcern::DoNotEncoder when disable_url_encoding is truthy" do
      agent.options['disable_url_encoding'] = true
      expect(agent.faraday.options.params_encoder).to eq(WebRequestConcern::DoNotEncoder)
      agent.options['disable_url_encoding'] = 'true'
      expect(agent.faraday.options.params_encoder).to eq(WebRequestConcern::DoNotEncoder)
    end

    describe "redirect follow" do
      it "should use FollowRedirects by default" do
        expect(agent.faraday.builder.handlers).to include(FaradayMiddleware::FollowRedirects)
      end

      it "should not use FollowRedirects when disabled" do
        agent.options['disable_redirect_follow'] = true
        expect(agent.faraday.builder.handlers).not_to include(FaradayMiddleware::FollowRedirects)
      end
    end
  end

  describe WebRequestConcern::DoNotEncoder do
    it "should not encode special characters" do
      expect(WebRequestConcern::DoNotEncoder.encode('GetRss?CategoryNr=39207' => 'test')).to eq('GetRss?CategoryNr=39207=test')
    end

    it "should work without a value present" do
      expect(WebRequestConcern::DoNotEncoder.encode('GetRss?CategoryNr=39207' => nil)).to eq('GetRss?CategoryNr=39207')
    end

    it "should work without an empty value" do
      expect(WebRequestConcern::DoNotEncoder.encode('GetRss?CategoryNr=39207' => '')).to eq('GetRss?CategoryNr=39207=')
    end

    it "should return the value when decoding" do
      expect(WebRequestConcern::DoNotEncoder.decode('val')).to eq(['val'])
    end
  end
end
