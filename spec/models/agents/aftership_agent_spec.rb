require 'rails_helper'

describe Agents::AftershipAgent do
  before do

    @opts = {
      "api_key" => '800deeaf-e285-9d62-bc90-j999c1973cc9',
      "get" => 'trackings'
    }

    @checker = Agents::AftershipAgent.new(:name => "tectonic", :options => @opts)
    @checker.user = users(:bob)
    @checker.save!
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

  describe "get request must exist" do
    it "should check that validation added if get does not exist" do
      opts = @opts.tap { |o| o.delete('get') }
      @checker = Agents::AftershipAgent.new(:name => "tectonic", :options => opts)
      @checker.user = users(:bob)
      expect(@checker.save).to eq false
      expect(@checker.errors.full_messages.first).to eq("You need to specify a get request")
    end
  end
end
