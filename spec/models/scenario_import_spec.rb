require 'spec_helper'

describe ScenarioImport do
  describe "initialization" do
    it "is initialized with an attributes hash" do
      ScenarioImport.new(:url => "http://google.com").url.should == "http://google.com"
    end
  end

  describe "validations" do
    subject { ScenarioImport.new }
    let(:valid_json) { { :name => "some scenario", :guid => "someguid" }.to_json }
    let(:invalid_json) { { :name => "some scenario missing a guid" }.to_json }

    it "is not valid when none of file, url, or data are present" do
      subject.should_not be_valid
      subject.should have(1).error_on(:base)
      subject.errors[:base].should include("Please provide either a Scenario JSON File or a Public Scenario URL.")
    end

    describe "data" do
      it "should be invalid with invalid data" do
        subject.data = invalid_json
        subject.should_not be_valid
        subject.should have(1).error_on(:base)

        subject.data = "foo"
        subject.should_not be_valid
        subject.should have(1).error_on(:base)

        # It also clears the data when invalid
        subject.data.should be_nil
      end

      it "should be valid with valid data" do
        subject.data = valid_json
        subject.should be_valid
      end
    end

    describe "url" do
      it "should be invalid with an unreasonable URL" do
        subject.url = "foo"
        subject.should_not be_valid
        subject.should have(1).error_on(:url)
        subject.errors[:url].should include("appears to be invalid")
      end

      it "should be invalid when the referenced url doesn't contain a scenario" do
        stub_request(:get, "http://example.com/scenarios/1/export.json").to_return(:status => 200, :body => invalid_json)
        subject.url = "http://example.com/scenarios/1/export.json"
        subject.should_not be_valid
        subject.errors[:base].should include("The provided data does not appear to be a valid Scenario.")
      end

      it "should be valid when the url points to a valid scenario" do
        stub_request(:get, "http://example.com/scenarios/1/export.json").to_return(:status => 200, :body => valid_json)
        subject.url = "http://example.com/scenarios/1/export.json"
        subject.should be_valid
      end
    end

    describe "file" do
      it "should be invalid when the uploaded file doesn't contain a scenario" do
        subject.file = StringIO.new("foo")
        subject.should_not be_valid
        subject.errors[:base].should include("The provided data does not appear to be a valid Scenario.")

        subject.file = StringIO.new(invalid_json)
        subject.should_not be_valid
        subject.errors[:base].should include("The provided data does not appear to be a valid Scenario.")
      end

      it "should be valid with a valid uploaded scenario" do
        subject.file = StringIO.new(valid_json)
        subject.should be_valid
      end
    end
  end
end