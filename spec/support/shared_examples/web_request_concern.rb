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
end