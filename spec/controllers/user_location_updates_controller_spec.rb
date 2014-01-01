require 'spec_helper'

describe UserLocationUpdatesController do
  before do
    @agent = Agent.build_for_type("Agents::UserLocationAgent", users(:bob), :name => "something", :options => { :secret => "my_secret" })
    @agent.save!
  end

  it "should create events without requiring login" do
    post :create, :user_id => users(:bob).to_param, :secret => "my_secret", :longitude => 123, :latitude => 45, :something => "else"
    @agent.events.last.payload.should == { 'longitude' => "123", 'latitude' => "45", 'something' => "else" }
    @agent.events.last.lat.should == 45
    @agent.events.last.lng.should == 123
  end

  it "should only consider Agents::UserLocationAgents for the given user" do
    @jane_agent = Agent.build_for_type("Agents::UserLocationAgent", users(:jane), :name => "something", :options => { :secret => "my_secret" })
    @jane_agent.save!

    post :create, :user_id => users(:bob).to_param, :secret => "my_secret", :longitude => 123, :latitude => 45, :something => "else"
    @agent.events.last.payload.should == { 'longitude' => "123", 'latitude' => "45", 'something' => "else" }
    @jane_agent.events.should be_empty
  end

  it "should raise a 404 error when given an invalid user id" do
    post :create, :user_id => "123", :secret => "not_my_secret", :longitude => 123, :latitude => 45, :something => "else"
    response.should be_missing
  end

  it "should only look at agents with the given secret" do
    @agent2 = Agent.build_for_type("Agents::UserLocationAgent", users(:bob), :name => "something", :options => { :secret => "my_secret2" })
    @agent2.save!

    lambda {
      post :create, :user_id => users(:bob).to_param, :secret => "my_secret2", :longitude => 123, :latitude => 45, :something => "else"
      @agent2.events.last.payload.should == { 'longitude' => "123", 'latitude' => "45", 'something' => "else" }
    }.should_not change { @agent.events.count }
  end
end