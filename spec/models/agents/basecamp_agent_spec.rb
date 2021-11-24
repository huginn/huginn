require 'rails_helper'
require 'models/concerns/oauthable'

describe Agents::BasecampAgent do
  it_behaves_like Oauthable

  before(:each) do
    stub_request(:get, /events.json$/).to_return(
      :body => File.read(Rails.root.join("spec/data_fixtures/basecamp.json")),
      :status => 200,
      :headers => {"Content-Type" => "text/json"}
    )
    stub_request(:get, /projects.json$/).to_return(
      :body => JSON.dump([{name: 'test', id: 1234},{name: 'test1', id: 1235}]),
      :status => 200,
      :headers => {"Content-Type" => "text/json"}
    )
    stub_request(:get, /02:00$/).to_return(
      :body => File.read(Rails.root.join("spec/data_fixtures/basecamp.json")),
      :status => 200,
      :headers => {"Content-Type" => "text/json"}
    )
    @valid_params = { :project_id => 6789 }

    @checker = Agents::BasecampAgent.new(:name => "somename", :options => @valid_params)
    @checker.service = services(:generic)
    @checker.user = users(:jane)
    @checker.save!

    stub(services(:generic)).refresh_token!
  end

  describe "validating" do
    before do
      expect(@checker).to be_valid
    end

    it "should require the basecamp project_id" do
      @checker.options['project_id'] = nil
      expect(@checker).not_to be_valid
    end

  end

  describe "helpers" do
    it "should generate a correct request options hash" do
      expect(@checker.send(:request_options)).to eq({headers: {"User-Agent" => "Huginn - https://github.com/huginn/huginn", "Authorization" => 'Bearer "1234token"'}})
    end

    it "should generate the correct events url" do
      expect(@checker.send(:events_url)).to eq("https://basecamp.com/12345/api/v1/projects/6789/events.json")
    end

    it "should generate the correct projects url" do
      expect(@checker.send(:projects_url)).to eq("https://basecamp.com/12345/api/v1/projects.json")
    end

    it "should not provide the since attribute on first run" do
      expect(@checker.send(:query_parameters)).to eq({})
    end

    it "should provide the since attribute after the first run" do
      time = (Time.now-1.minute).iso8601
      @checker.memory[:last_event] = time
      @checker.save
      expect(@checker.reload.send(:query_parameters)).to eq({:query => {:since => time}})
    end
  end

  describe "#complete_project_id" do
    it "should return a array of hashes" do
      expect(@checker.complete_project_id).to eq [{text: 'test (1234)', id: 1234}, {text: 'test1 (1235)', id: 1235}]
    end
  end

  describe "#check" do
    it "should not emit events on its first run" do
      expect { @checker.check }.to change { Event.count }.by(0)
      expect(@checker.memory[:last_event]).to eq '2014-04-17T10:25:31.000+02:00'
    end
    it "should check that initial run creates an event" do
      @checker.memory[:last_event] = '2014-04-17T10:25:31.000+02:00'
      expect { @checker.check }.to change { Event.count }.by(1)
    end
  end

  describe "#working?" do
    it "it is working when at least one event was emitted" do
      expect(@checker).not_to be_working
      @checker.memory[:last_event] = '2014-04-17T10:25:31.000+02:00'
      @checker.check
      expect(@checker.reload).to be_working
    end
  end
end
