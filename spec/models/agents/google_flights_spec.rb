require 'rails_helper'

describe Agents::GoogleFlightsAgent do
  before do

    stub_request(:post, "https://www.googleapis.com/qpxExpress/v1/trips/search?key=800deeaf-e285-9d62-bc90-j999c1973cc9").to_return(
      :body => File.read(Rails.root.join("spec/data_fixtures/qpx.json")),
      :status => 200,
      :headers => {"Content-Type" => "application/json"}
    )

    @opts = {
      'qpx_api_key' => '800deeaf-e285-9d62-bc90-j999c1973cc9',
      'adultCount' => 1,
      'origin' => 'BOS',
      'destination' => 'SFO',
      'date' => '2016-04-11',
      'childCount' => 0,
      'infantInSeatCount' => 0,
      'infantInLapCount'=> 0,
      'seniorCount'=> 0,
      'solutions'=> 3
    }

    @checker = Agents::GoogleFlightsAgent.new(:name => "tectonic", :options => @opts)
    @checker.user = users(:bob)
    @checker.save!
  end

  describe '#helpers' do
    it "should generate the correct events url" do
      expect(@checker.send(:event_url)).to eq("https://www.googleapis.com/qpxExpress/v1/trips/search?key=800deeaf-e285-9d62-bc90-j999c1973cc9")
    end
  end

  describe "#that checker should be valid" do
    it "should check that the object is valid" do
      expect(@checker).to be_valid
    end

    it "should require credentials" do
      @checker.options['qpx_api_key'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require adultCount" do 
      @checker.options['adultCount'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require Origin" do 
      @checker.options['origin'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require Destination" do 
      @checker.options['destination'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require Date" do 
      @checker.options['date'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require childCount" do 
      @checker.options['childCount'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require Infant In Seat Count" do 
      @checker.options['infantInSeatCount'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require Infant In Lab Count" do 
      @checker.options['infantInLapCount'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require Senior Count" do 
      @checker.options['seniorCount'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require Solutions" do 
      @checker.options['solutions'] = nil
      expect(@checker).not_to be_valid
    end

    it "should require Return Date" do
      @checker.options['roundtrip'] = true
      @checker.options['return_date'] = nil
      expect(@checker).not_to be_valid
    end
  end

  describe '#check' do
    it "should check that initial run creates an event" do
      @checker.memory[:latestTicketingTime] = '2016-03-24T23:59-04:00'
      expect { @checker.check }.to change { Event.count }.by(1)
    end
  end
end
