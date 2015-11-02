require 'rails_helper'

describe Agents::JiraAgent do
  before(:each) do
    stub_request(:get, /atlassian.com/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/jira.json")), :status => 200, :headers => {"Content-Type" => "text/json"})

    @valid_params = {
      :username   => "user",
      :password   => "pass",
      :jira_url => 'https://jira.atlassian.com',
      :jql => 'resolution = unresolved',
      :expected_update_period_in_days => '7',
      :timeout => '1'
    }

    @checker = Agents::JiraAgent.new(:name => "jira-agent", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!
  end

  describe "validating" do
    before do
      expect(@checker).to be_valid
    end

    it "should work without username" do
      @checker.options['username'] = nil
      expect(@checker).to be_valid
    end

    it "should require the jira password if username is specified" do
      @checker.options['username'] = 'user'
      @checker.options['password'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require the jira url" do
      @checker.options['jira_url'] = nil
      expect(@checker).not_to be_valid
    end

    it "should work without jql" do
      @checker.options['jql'] = nil
      expect(@checker).to be_valid
    end

    it "should require the expected_update_period_in_days" do
      @checker.options['expected_update_period_in_days'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require timeout" do
      @checker.options['timeout'] = nil
      expect(@checker).not_to be_valid
    end
  end

  describe "helpers" do
    it "should generate a correct request options hash" do
      expect(@checker.send(:request_options)).to eq({:basic_auth=>{:username=>"user", :password=>"pass"}, :headers => {"User-Agent" => "Huginn (https://github.com/cantino/huginn)"}})
    end

    it "should generate a correct request url" do
      expect(@checker.send(:request_url, 'foo=bar', 10)).to eq("https://jira.atlassian.com/rest/api/2/search?jql=foo%3Dbar&fields=*all&startAt=10")
    end


    it "should not set the 'since' time on the first run" do
      expected_url = "https://jira.atlassian.com/rest/api/2/search?jql=resolution+%3D+unresolved&fields=*all&startAt=0"
      expected_headers = {:headers=>{"User-Agent"=>"Huginn (https://github.com/cantino/huginn)"}, :basic_auth=>{:username=>"user", :password=>"pass"}}
      reply = JSON.parse(File.read(Rails.root.join("spec/data_fixtures/jira.json")))
      mock(@checker).get(expected_url, expected_headers).returns(reply)

      @checker.check
    end

    it "should provide set the 'since' time after the first run" do
      expected_url_1 = "https://jira.atlassian.com/rest/api/2/search?jql=resolution+%3D+unresolved&fields=*all&startAt=0"
      expected_url_2 = "https://jira.atlassian.com/rest/api/2/search?jql=resolution+%3D+unresolved&fields=*all&startAt=0"

      expected_headers = {:headers=>{"User-Agent"=>"Huginn (https://github.com/cantino/huginn)"}, :basic_auth=>{:username=>"user", :password=>"pass"}}
      reply = JSON.parse(File.read(Rails.root.join("spec/data_fixtures/jira.json")))

      mock(@checker) do 
        get(expected_url_1, expected_headers).returns(reply)
        # time specification
        get(/\d+-\d+-\d+\+\d+%3A\d+/, expected_headers).returns(reply)
      end

      @checker.check
      @checker.check
    end
  end
  describe "#check" do
    it "should be able to retrieve issues" do
      reply = JSON.parse(File.read(Rails.root.join("spec/data_fixtures/jira.json")))
      mock(@checker).get(anything,anything).returns(reply)

      expect { @checker.check }.to change { Event.count }.by(50)
    end
  end

  describe "#working?" do
    it "it is working when at least one event was emited" do
      expect(@checker).not_to be_working
      @checker.check
      expect(@checker.reload).to be_working
    end
  end
end
