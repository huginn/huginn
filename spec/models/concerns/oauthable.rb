require 'rails_helper'

module Agents
  class OauthableTestAgent < Agent
    include Oauthable
  end
end

shared_examples_for Oauthable do
  before(:each) do
    @agent = described_class.new(:name => "somename")
    @agent.user = users(:jane)
  end

  it "should be oauthable" do
    expect(@agent.oauthable?).to eq(true)
  end

  describe "valid_services_for" do
    it "should return all available services without specifying valid_oauth_providers" do
      @agent = Agents::OauthableTestAgent.new
      expect(@agent.valid_services_for(users(:bob)).collect(&:id).sort).to eq([services(:generic), services(:global)].collect(&:id).sort)
    end

    it "should filter the services based on the agent defaults" do
      expect(@agent.valid_services_for(users(:bob)).to_a).to eq(Service.where(provider: @agent.valid_oauth_providers))
    end
  end
end
