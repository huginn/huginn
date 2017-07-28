require 'rails_helper'

describe Agents::GithubNotificationsAgent do
  before do
    @valid_params = {
      name: "somename",
      options: {
        access_token: 'sometoken',
        events: "multiple",
        last_modified: true
      }
    }

    stub_request(:get, /github\.com/).to_return(
      :body => File.read(Rails.root.join("spec/data_fixtures/github_notifications.json")),
      :status => 200,
      :headers => {"Content-Type" => "text/json", "Last-Modified" => 'Thu, 25 Oct 2012 15:16:27 GMT'}
    )

    @checker = Agents::GithubNotificationsAgent.new(@valid_params)
    @checker.user = users(:jane)
    @checker.save!

  end

  describe "#check" do
    it "checks if it can handle multiple events" do
      expect {
        @checker.check()
      }.to change { Event.count }.by(2)
    end
  end

  describe "helpers" do
    it "should generate a correct request options hash on the first run" do
      expect(@checker.send(:request_options)).to eq({
        headers: {"User-Agent" => "Huginn (https://github.com/cantino/huginn)"},
        query: {access_token: @checker.options['access_token']}
      })
    end

    it "should generate a correct request options hash on consecutive runs" do
      time = (Time.now-1.minute).iso8601
      @checker.memory[:last_modified] = time
      @checker.save
      expect(@checker.reload.send(:request_options)).to eq({
        headers: {"User-Agent" => "Huginn (https://github.com/cantino/huginn)", "If-Modified-Since" => time},
        query: {access_token: @checker.options['access_token']}
      })
    end

    it "should generate a correct request options hash on consecutive runs with last_modified == false" do
      @checker.options['last_modified'] = 'false'
      @checker.memory[:last_modified] = Time.now
      @checker.save
      expect(@checker.reload.send(:request_options)).to eq({
        headers: {"User-Agent" => "Huginn (https://github.com/cantino/huginn)"},
        query: {access_token: @checker.options['access_token']}
      })
    end

  end

  describe "validation" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate presence of access_token key" do
      @checker.options[:access_token] = nil
      expect(@checker).not_to be_valid
    end

    it "should validate last_modified is boolean" do
      @checker.options[:last_modified] = 'test'
      expect(@checker).not_to be_valid
    end

    it "should validate interval is positive integer, if present" do
      @checker.options[:interval] = "asdf"
      expect(@checker).not_to be_valid
    end

    it "should validate interval is positive integer, if present" do
      @checker.options[:interval] = "-1"
      expect(@checker).not_to be_valid
    end
  end
end
