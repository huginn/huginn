require 'rails_helper'

describe LifxClient do
  describe "#get_selectors" do
    let(:client) { LifxClient.new("token", "all") }
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