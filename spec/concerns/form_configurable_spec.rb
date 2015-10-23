require 'rails_helper'

describe FormConfigurable do
  class Agent1
    include FormConfigurable

    def validate_test
      true
    end

    def complete_test
      [{name: 'test', value: 1234}]
    end
  end

  class Agent2 < Agent
  end

  before(:all) do
    @agent1 = Agent1.new
    @agent2 = Agent2.new
  end

  it "#is_form_configurable" do
    expect(@agent1.is_form_configurable?).to be true
    expect(@agent2.is_form_configurable?).to be false
  end

  describe "#validete_option" do
    it "should call the validation method if it is defined" do
      expect(@agent1.validate_option('test')).to be true
    end

    it "should return false of the method is undefined" do
      expect(@agent1.validate_option('undefined')).to be false
    end
  end

  it "#complete_option" do
    expect(@agent1.complete_option('test')).to eq [{name: 'test', value: 1234}]
  end

  describe "#form_configurable" do
    it "should raise an ArgumentError for invalid  options" do
      expect { Agent1.form_configurable(:test, invalid: true) }.to raise_error(ArgumentError)
    end

    it "should raise an ArgumentError when not providing an array with type: array" do
      expect { Agent1.form_configurable(:test, type: :array, values: 1) }.to raise_error(ArgumentError)
    end

    it "should not require any options for the default values" do
      expect { Agent1.form_configurable(:test) }.to change(Agent1, :form_configurable_attributes).by(['test'])
    end
  end
end