require 'spec_helper'

shared_examples_for EmailConcern do
  let(:valid_options) {
    {
      :subject => "hello!",
      :expected_receive_period_in_days => "2"
    }
  }

  let(:agent) do
    _agent = described_class.new(:name => "some email agent", :options => valid_options)
    _agent.user = users(:jane)
    _agent
  end

  describe "validations" do
    it "should be valid" do
      agent.should be_valid
    end

    it "should validate the presence of 'subject'" do
      agent.options['subject'] = ''
      agent.should_not be_valid

      agent.options['subject'] = nil
      agent.should_not be_valid
    end

    it "should validate the presence of 'expected_receive_period_in_days'" do
      agent.options['expected_receive_period_in_days'] = ''
      agent.should_not be_valid

      agent.options['expected_receive_period_in_days'] = nil
      agent.should_not be_valid
    end

    it "should validate that recipients, when provided, is one or more valid email addresses" do
      agent.options['recipients'] = ''
      agent.should be_valid

      agent.options['recipients'] = nil
      agent.should be_valid

      agent.options['recipients'] = 'bob@example.com'
      agent.should be_valid

      agent.options['recipients'] = ['bob@example.com']
      agent.should be_valid

      agent.options['recipients'] = ['bob@example.com', 'jane@example.com']
      agent.should be_valid

      agent.options['recipients'] = ['bob@example.com', 'example.com']
      agent.should_not be_valid

      agent.options['recipients'] = ['hi!']
      agent.should_not be_valid

      agent.options['recipients'] = { :foo => "bar" }
      agent.should_not be_valid

      agent.options['recipients'] = "wut"
      agent.should_not be_valid
    end
  end

  describe "#recipients" do
    it "defaults to the user's email address" do
      agent.recipients.should == [users(:jane).email]
    end

    it "wraps a string with an array" do
      agent.options['recipients'] = 'bob@bob.com'
      agent.recipients.should == ['bob@bob.com']
    end

    it "handles an array" do
      agent.options['recipients'] = ['bob@bob.com', 'jane@jane.com']
      agent.recipients.should == ['bob@bob.com', 'jane@jane.com']
    end

    it "interpolates" do
      agent.options['recipients'] = "{{ username }}@{{ domain }}"
      agent.recipients('username' => 'bob', 'domain' => 'example.com').should == ["bob@example.com"]
    end
  end
end