require 'rails_helper'

describe Service do
  before(:each) do
    @user = users(:bob)
  end

  describe "#toggle_availability!" do
    it "should toggle the global flag" do
      @service = services(:generic)
      expect(@service.global).to eq(false)
      @service.toggle_availability!
      expect(@service.global).to eq(true)
      @service.toggle_availability!
      expect(@service.global).to eq(false)
    end

    it "disconnects agents and disables them if the previously global service is made private again" do
      agent = agents(:bob_basecamp_agent)
      jane_agent = agents(:jane_basecamp_agent)

      service = agent.service
      service.toggle_availability!
      expect(service.agents.length).to eq(2)

      service.toggle_availability!
      jane_agent.reload
      expect(jane_agent.service_id).to be_nil
      expect(jane_agent.disabled).to be true

      service.reload
      expect(service.agents.length).to eq(1)
    end
  end

  it "disables all agents before beeing destroyed" do
    agent = agents(:bob_basecamp_agent)
    service = agent.service
    service.destroy
    agent.reload
    expect(agent.service_id).to be_nil
    expect(agent.disabled).to be true
  end

  describe "preparing for a request" do
    before(:each) do
      @service = services(:generic)
    end

    it "should not update the token if the token never expires" do
      @service.expires_at = nil
      expect(@service.prepare_request).to eq(nil)
    end

    it "should not update the token if the token is still valid" do
      @service.expires_at = Time.now + 1.hour
      expect(@service.prepare_request).to eq(nil)
    end

    it "should call refresh_token! if the token expired" do
      stub(@service).refresh_token! { @service }
      @service.expires_at = Time.now - 1.hour
      expect(@service.prepare_request).to eq(@service)
    end
  end

  describe "updating the access token" do
    before(:each) do
      @service = services(:generic)
    end

    it "should return the correct endpoint" do
      @service.provider = '37signals'
      expect(@service.send(:endpoint).to_s).to eq("https://launchpad.37signals.com/authorization/token")
    end

    it "should update the token" do
      stub_request(:post, "https://launchpad.37signals.com/authorization/token?client_id=TESTKEY&client_secret=TESTSECRET&refresh_token=refreshtokentest&type=refresh").
        to_return(:status => 200, :body => '{"expires_in":1209600,"access_token": "NEWTOKEN"}', :headers => {})
      @service.provider = '37signals'
      @service.refresh_token = 'refreshtokentest'
      @service.refresh_token!
      expect(@service.token).to eq('NEWTOKEN')
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
      expect(service.name).to eq('johnqpublic')
      expect(service.uid).to eq('123456')
      expect(service.provider).to eq('twitter')
      expect(service.token).to eq('a1b2c3d4...')
      expect(service.secret).to eq('abcdef1234')
    end

    it "should work with 37signals services" do
      signals = JSON.parse(File.read(Rails.root.join('spec/data_fixtures/services/37signals.json')))
      expect {
        service = @user.services.initialize_or_update_via_omniauth(signals)
        service.save!
      }.to change { @user.services.count }.by(1)
      service = @user.services.first
      expect(service.provider).to eq('37signals')
      expect(service.name).to eq('Dominik Sander')
      expect(service.token).to eq('abcde')
      expect(service.uid).to eq('12345')
      expect(service.refresh_token).to eq('fghrefresh')
      expect(service.options[:user_id]).to eq(12345)
      service.expires_at = Time.at(1401554352)
    end

    it "should work with github services" do
      signals = JSON.parse(File.read(Rails.root.join('spec/data_fixtures/services/github.json')))
      expect {
        service = @user.services.initialize_or_update_via_omniauth(signals)
        service.save!
      }.to change { @user.services.count }.by(1)
      service = @user.services.first
      expect(service.provider).to eq('github')
      expect(service.name).to eq('dsander')
      expect(service.uid).to eq('12345')
      expect(service.token).to eq('agithubtoken')
    end
  end

  describe 'omniauth options provider registry for non-conforming omniauth responses' do
    describe '.register_options_provider' do
      before do
        Service.register_options_provider('test-omniauth-provider') do |omniauth|
          { name: omniauth['special_field'] }
        end
      end

      after do
        Service.option_providers.delete('test-omniauth-provider')
      end

      it 'allows gem developers to add their own options provider to the registry' do
        actual_options = Service.get_options({
          'provider' => 'test-omniauth-provider',
          'special_field' => 'A Great Name'
        })

        expect(actual_options[:name]).to eq('A Great Name')
      end
    end
  end
end
