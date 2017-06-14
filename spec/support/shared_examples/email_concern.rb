require 'rails_helper'

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
      expect(agent).to be_valid
    end

    it "should validate the presence of 'subject'" do
      agent.options['subject'] = ''
      expect(agent).not_to be_valid

      agent.options['subject'] = nil
      expect(agent).not_to be_valid
    end

    it "should validate the presence of 'expected_receive_period_in_days'" do
      agent.options['expected_receive_period_in_days'] = ''
      expect(agent).not_to be_valid

      agent.options['expected_receive_period_in_days'] = nil
      expect(agent).not_to be_valid
    end

    it "should validate that recipients, when provided, is one or more valid email addresses or Liquid commands" do
      agent.options['recipients'] = ''
      expect(agent).to be_valid

      agent.options['recipients'] = nil
      expect(agent).to be_valid

      agent.options['recipients'] = 'bob@example.com'
      expect(agent).to be_valid

      agent.options['recipients'] = ['bob@example.com']
      expect(agent).to be_valid

      agent.options['recipients'] = '{{ email }}'
      expect(agent).to be_valid

      agent.options['recipients'] = '{% if x %}a@x{% else %}b@y{% endif %}'
      expect(agent).to be_valid

      agent.options['recipients'] = ['bob@example.com', 'jane@example.com']
      expect(agent).to be_valid

      agent.options['recipients'] = ['bob@example.com', 'example.com']
      expect(agent).not_to be_valid

      agent.options['recipients'] = ['hi!']
      expect(agent).not_to be_valid

      agent.options['recipients'] = { :foo => "bar" }
      expect(agent).not_to be_valid

      agent.options['recipients'] = "wut"
      expect(agent).not_to be_valid
    end
  end

  describe "#recipients" do
    it "defaults to the user's email address" do
      expect(agent.recipients).to eq([users(:jane).email])
    end

    it "wraps a string with an array" do
      agent.options['recipients'] = 'bob@bob.com'
      expect(agent.recipients).to eq(['bob@bob.com'])
    end

    it "handles an array" do
      agent.options['recipients'] = ['bob@bob.com', 'jane@jane.com']
      expect(agent.recipients).to eq(['bob@bob.com', 'jane@jane.com'])
    end

    it "interpolates" do
      agent.options['recipients'] = "{{ username }}@{{ domain }}"
      expect(agent.recipients('username' => 'bob', 'domain' => 'example.com')).to eq(["bob@example.com"])
    end
  end
end
