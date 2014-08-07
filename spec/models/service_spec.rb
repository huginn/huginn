require 'spec_helper'

describe Service do
  before(:each) do
    @user = users(:bob)
  end

  it "should toggle the global flag" do
    @service = services(:generic)
    @service.global.should == false
    @service.toggle_availability!
    @service.global.should == true
    @service.toggle_availability!
    @service.global.should == false
  end

  it "disables all agents before beeing destroyed" do
    agent = agents(:bob_basecamp_agent)
    service = agent.service
    service.destroy
    agent.reload
    agent.service_id.should be_nil
    agent.disabled.should be_true
  end

  describe "preparing for a request" do
    before(:each) do
      @service = services(:generic)
    end

    it "should not update the token if the token never expires" do
      @service.expires_at = nil
      @service.prepare_request.should == nil
    end

    it "should not update the token if the token is still valid" do
      @service.expires_at = Time.now + 1.hour
      @service.prepare_request.should == nil
    end

    it "should call refresh_token! if the token expired" do
      stub(@service).refresh_token! { @service }
      @service.expires_at = Time.now - 1.hour
      @service.prepare_request.should == @service
    end
  end

  describe "updating the access token" do
    before(:each) do
      @service = services(:generic)
    end

    it "should return the correct endpoint" do
      @service.provider = '37signals'
      @service.send(:endpoint).to_s.should == "https://launchpad.37signals.com/authorization/token"
    end

    it "should update the token" do
      stub_request(:post, "https://launchpad.37signals.com/authorization/token?client_id=TESTKEY&client_secret=TESTSECRET&refresh_token=refreshtokentest&type=refresh").
        to_return(:status => 200, :body => '{"expires_in":1209600,"access_token": "NEWTOKEN"}', :headers => {})
      @service.provider = '37signals'
      @service.refresh_token = 'refreshtokentest'
      @service.refresh_token!
      @service.token.should == 'NEWTOKEN'
    end
  end

  describe "creating services via omniauth" do
    it "should work with twitter services" do
      twitter = JSON.parse(File.read(Rails.root.join('spec/data_fixtures/services/twitter.json')))
      expect {
        service = @user.services.initialize_or_update_via_omniauth(twitter)
        service.save!
      }.to change { @user.services.count }.by(1)
      service = @user.services.first
      service.name.should == 'johnqpublic'
      service.provider.should == 'twitter'
      service.token.should == 'a1b2c3d4...'
      service.secret.should == 'abcdef1234'
    end
    it "should work with 37signals services" do
      signals = JSON.parse(File.read(Rails.root.join('spec/data_fixtures/services/37signals.json')))
      expect {
        service = @user.services.initialize_or_update_via_omniauth(signals)
        service.save!
      }.to change { @user.services.count }.by(1)
      service = @user.services.first
      service.provider.should == '37signals'
      service.name.should == 'Dominik Sander'
      service.token.should == 'abcde'
      service.refresh_token.should == 'fghrefresh'
      service.options[:user_id].should == 12345
      service.expires_at = Time.at(1401554352)
    end
    it "should work with github services" do
      signals = JSON.parse(File.read(Rails.root.join('spec/data_fixtures/services/github.json')))
      expect {
        service = @user.services.initialize_or_update_via_omniauth(signals)
        service.save!
      }.to change { @user.services.count }.by(1)
      service = @user.services.first
      service.provider.should == 'github'
      service.name.should == 'dsander'
      service.token.should == 'agithubtoken'
    end
  end
end
