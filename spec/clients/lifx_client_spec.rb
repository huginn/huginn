require 'rails_helper'

describe LifxClient do
  let(:selector) { "all" }
  let(:client) { LifxClient.new("t0k3n", selector) }
    
  describe "#pulse" do
    it "calls the Lifx API with the specified options" do
      expected_options = {color: "red"}
      stub = stub_request(:post, "https://api.lifx.com/v1/lights/all/effects/pulse")
        .with(:body => expected_options, :headers => {'Authorization' => "Bearer t0k3n"})

      client.pulse(expected_options)
      expect(stub).to have_been_requested
    end
  end
  
  describe "#toggle" do
    it "calls the Lifx API with the specified options" do
      expected_options = {duration: "3"}
      stub = stub_request(:post, "https://api.lifx.com/v1/lights/all/toggle")
        .with(:body => expected_options, :headers => {'Authorization' => "Bearer t0k3n"})

      client.toggle(expected_options)
      expect(stub).to have_been_requested
    end
  end
  
  describe "#get_selectors" do
    let(:selectors) { client.get_selectors }
    
    before do
      stub_request(:get, "https://api.lifx.com/v1/lights/all").
        to_return(:body => <<-JSON
          [
            {
              "id": "ad86a8d68",
              "label": "light1",
              "group": {
                "id": "1c8de82b81f445e7cfaafae49b259c71",
                "name": "group1"
              }
            },
            {
              "id": "cb7868796b",
              "label": "light2",
              "group": {
                "id": "1c8de82b81f445e7cfaafae49b259c71",
                "name": "group1"
              }
            }
          ]
          JSON
        )

    end
      
    it "returns 'all' as the first selector" do
      expect(selectors.first).to eq("all")
    end
    
    it "returns light labels with a 'label:' prefix" do
      expect(selectors.detect{ |s| s.include?("light1") }).to eq("label:light1")
    end
    
    it "returns group names with a 'group:' prefix" do
      expect(selectors.detect{ |s| s.include?("group1") }).to eq("group:group1")
    end
    
    it "de-duplicates groups" do
      expect(selectors.select{ |s| s.include?("group1") }.length).to eq(1)
    end
  end
end
