require 'spec_helper'
describe Agents::PublicTransportAgent do
  before do
    valid_params = {
      "name" => "sf muni agent",
      "options" => {
        "alert_window_in_minutes" => "20",
        "stops" => ['N|5221', 'N|5215'],
        "agency" => "sf-muni"
      }
    }
    @agent = Agents::PublicTransportAgent.new(valid_params)
    @agent.user = users(:bob)
    @agent.save!
  end

  describe "#check" do
    before do
      stub_request(:get, "http://webservices.nextbus.com/service/publicXMLFeed?a=sf-muni&command=predictionsForMultiStops&stops=N%7C5215").
         with(:headers => {'User-Agent'=>'Typhoeus - https://github.com/typhoeus/typhoeus'}).
         to_return(:status => 200, :body => File.read(Rails.root.join("spec/data_fixtures/public_transport_agent.xml")), :headers => {})
    end

    it "should create 4 events" do
      lambda { @agent.check }.should change {@agent.events.count}.by(4)
    end

    it "should add 4 items to memory" do
      time_travel_to Time.parse("2014-01-14 20:21:30 +0500") do
        @agent.memory.should == {}
        @agent.check
        @agent.save
        @agent.reload.memory.should == {"existing_routes" => [
            {"stopTag"=>"5221", "tripTag"=>"5840324", "epochTime"=>"1389706393991", "currentTime"=>Time.now.to_s},
            {"stopTag"=>"5221", "tripTag"=>"5840083", "epochTime"=>"1389706512784", "currentTime"=>Time.now.to_s},
            {"stopTag"=>"5215", "tripTag"=>"5840324", "epochTime"=>"1389706282012", "currentTime"=>Time.now.to_s},
            {"stopTag"=>"5215", "tripTag"=>"5840083", "epochTime"=>"1389706400805", "currentTime"=>Time.now.to_s}
          ]
        }
      end
    end

    it "should not create events twice" do
      lambda { @agent.check }.should change {@agent.events.count}.by(4)
      lambda { @agent.check }.should_not change {@agent.events.count}
    end

    it "should reset memory after 2 hours" do
      time_travel_to Time.parse("2014-01-14 20:21:30 +0500") do
        lambda { @agent.check }.should change {@agent.events.count}.by(4)
      end
      time_travel_to "2014-01-14 23:21:30 +0500".to_time do
        @agent.cleanup_old_memory
        lambda { @agent.check }.should change {@agent.events.count}.by(4)
      end
    end
  end

  describe "validation" do
    it "should validate presence of stops" do
      @agent.options['stops'] = nil
      @agent.should_not be_valid
    end

    it "should validate presence of agency" do
      @agent.options['agency'] = ""
      @agent.should_not be_valid
    end

    it "should validate presence of alert_window_in_minutes" do
      @agent.options['alert_window_in_minutes'] = ""
      @agent.should_not be_valid
    end
  end
end
