require 'spec_helper'

shared_examples_for WebRequestConcern do
  let(:agent) do
    _agent = described_class.new(:name => "some agent", :options => @valid_options || {})
    _agent.user = users(:jane)
    _agent
  end

  describe "validations" do
    it "should be valid" do
      agent.should be_valid
    end

    it "should validate user_agent" do
      agent.options['user_agent'] = nil
      agent.should be_valid

      agent.options['user_agent'] = ""
      agent.should be_valid

      agent.options['user_agent'] = "foo"
      agent.should be_valid

      agent.options['user_agent'] = ["foo"]
      agent.should_not be_valid

      agent.options['user_agent'] = 1
      agent.should_not be_valid
    end

    it "should validate headers" do
      agent.options['headers'] = "blah"
      agent.should_not be_valid

      agent.options['headers'] = ""
      agent.should be_valid

      agent.options['headers'] = {}
      agent.should be_valid

      agent.options['headers'] = { 'foo' => 'bar' }
      agent.should be_valid
    end

    it "should validate basic_auth" do
      agent.options['basic_auth'] = "foo:bar"
      agent.should be_valid

      agent.options['basic_auth'] = ["foo", "bar"]
      agent.should be_valid

      agent.options['basic_auth'] = ""
      agent.should be_valid

      agent.options['basic_auth'] = nil
      agent.should be_valid

      agent.options['basic_auth'] = "blah"
      agent.should_not be_valid

      agent.options['basic_auth'] = ["blah"]
      agent.should_not be_valid
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

    it "should have the default value set by Faraday" do
      agent.user_agent.should == Faraday.new.headers[:user_agent]
    end

    it "should be overridden by the environment variable if present" do
      ENV['DEFAULT_HTTP_USER_AGENT'] = 'Huginn - https://github.com/cantino/huginn'
      agent.user_agent.should == 'Huginn - https://github.com/cantino/huginn'
    end

    it "should be overriden by the value in options if present" do
      agent.options['user_agent'] = 'Override'
      agent.user_agent.should == 'Override'
    end
  end
end
