require 'rails_helper'

describe TimeTracker do
  describe "#track" do
    it "tracks execution time" do
      tracked_result = TimeTracker.track { sleep(0.01) }
      expect(tracked_result.elapsed_time).to satisfy {|v| v > 0.01 && v < 0.1}
    end

    it "returns the proc return value" do
      tracked_result = TimeTracker.track { 42 }
      expect(tracked_result.result).to eq(42)
    end

    it "returns an object that behaves like the proc result" do
      tracked_result = TimeTracker.track { 42 }
      expect(tracked_result.to_i).to eq(42)
      expect(tracked_result + 1).to eq(43)
    end
  end
end
