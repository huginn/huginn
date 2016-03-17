require 'rails_helper'

describe Agents::QpxExpressAgent do
  before do

    stub_request(:get, "https://www.googleapis.com/qpxExpress/v1/trips/search").to_return(
      :body => File.read(Rails.root.join("spec/data_fixtures/qpx_express.json")),
      :status => 200,
      :headers => {"Content-Type" => "application/json"}
    )

    @opts = {
      "qpx_api_key" => '800deeaf-e285-9d62-bc90-j999c1973cc9'
    }

    @checker = Agents::QpxExpressAgent.new(:name => "tectonic", :options => @opts)
    @checker.user = users(:bob)
    @checker.save!
  end

  describe '#helpers' do
    it "should return the correct request header" do
      expect(@checker.send(:request_options)).to eq({:headers => {"Content-Type"=>"application/json"}})
    end

    it "should generate the correct events url" do
      expect(@checker.send(:event_url)).to eq("https://www.googleapis.com/qpxExpress/v1/trips/search?key")
    end
  end

  describe "#that checker should be valid" do
    it "should check that the aftership object is valid" do
      expect(@checker).to be_valid
    end

    it "should require credentials" do
      @checker.options['qpx_api_key'] = nil
      expect(@checker).not_to be_valid
    end
  end

  describe '#check' do
    it "should check that initial run creates an event" do
      @checker.memory[:last_updated_at] = '2016-03-15T14:01:05+00:00'
      expect { @checker.check }.to change { Event.count }.by(1)
    end
  end
end
