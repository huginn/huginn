require "rails_helper"

describe JsonWithIndifferentAccess do
  describe ".load" do
    it "loads JSON strings with indifferent access" do
      value = described_class.load('{"foo":"bar"}')

      expect(value[:foo]).to eq("bar")
      expect(value["foo"]).to eq("bar")
    end

    it "loads hashes with indifferent access" do
      value = described_class.load({ "foo" => "bar" })

      expect(value[:foo]).to eq("bar")
      expect(value["foo"]).to eq("bar")
    end

    it "loads nil as an empty hash with indifferent access" do
      value = described_class.load(nil)

      expect(value).to be_empty
      expect(value).to be_a(ActiveSupport::HashWithIndifferentAccess)
    end
  end
end
