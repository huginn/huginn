require 'rails_helper'

describe Agents::AftershipAgent do
  before do

    stub_request(:get, /trackings/).to_return(
      :body => File.read(Rails.root.join("spec/data_fixtures/aftership.json")),
      :status => 200,
      :headers => {"Content-Type" => "text/json"}
    )

    @opts = {
      "api_key" => '800deeaf-e285-9d62-bc90-j999c1973cc9',
      "path" => 'trackings'
    }

    @checker = Agents::AftershipAgent.new(:name => "tectonic", :options => @opts)
    @checker.user = users(:bob)
    @checker.save!
  end

  describe '#helpers' do
    it "should return the correct request header" do
      expect(@checker.send(:request_options)).to eq({:headers => {"aftership-api-key" => '800deeaf-e285-9d62-bc90-j999c1973cc9', "Content-Type"=>"application/json"}})
    end

    it "should generate the correct events url" do
      expect(@checker.send(:event_url)).to eq("https://api.aftership.com/v4/trackings")
    end

    it "should generate the correct specific tracking url" do
      @checker.options['path'] = "trackings/usps/9361289878905919630610"
      expect(@checker.send(:event_url)).to eq("https://api.aftership.com/v4/trackings/usps/9361289878905919630610")
    end

    it "should generate the correct last checkpoint url" do
      @checker.options['path'] = "last_checkpoint/usps/9361289878905919630610"
      expect(@checker.send(:event_url)).to eq("https://api.aftership.com/v4/last_checkpoint/usps/9361289878905919630610")
    end
  end

  describe "#that checker should be valid" do
    it "should check that the aftership object is valid" do
      expect(@checker).to be_valid
    end

    it "should require credentials" do
      @checker.options['api_key'] = nil
      expect(@checker).not_to be_valid
    end
  end

  describe "path request must exist" do
    it "should check that validation added if path does not exist" do
      opts = @opts.tap { |o| o.delete('path') }
      @checker = Agents::AftershipAgent.new(:name => "tectonic", :options => opts)
      @checker.user = users(:bob)
      expect(@checker.save).to eq false
      expect(@checker.errors.full_messages.first).to eq("You need to specify a path request")
    end
  end

  describe '#check' do
    it "should check that initial run creates an event" do
      @checker.memory[:last_updated_at] = '2016-03-15T14:01:05+00:00'
      expect { @checker.check }.to change { Event.count }.by(1)
    end
  end
end
