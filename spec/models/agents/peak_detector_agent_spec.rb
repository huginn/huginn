require 'rails_helper'

describe Agents::PeakDetectorAgent do
  before do
    @valid_params = {
        'name' => "my peak detector agent",
        'options' => {
          'expected_receive_period_in_days' => "2",
          'group_by_path' => "filter",
          'value_path' => "count",
          'message' => "A peak was found"
        }
    }

    @agent = Agents::PeakDetectorAgent.new(@valid_params)
    @agent.user = users(:bob)
    @agent.save!
  end

  describe "#receive" do
    it "tracks and groups by the group_by_path" do
      events = build_events(:keys => ['count', 'filter'],
                            :values => [[1, "something"], [2, "something"], [3, "else"]])
      @agent.receive events
      expect(@agent.memory['data']['something'].map(&:first)).to eq([1, 2])
      expect(@agent.memory['data']['something'].last.last).to be_within(10).of((100 - 1).hours.ago.to_i)
      expect(@agent.memory['data']['else'].first.first).to eq(3)
      expect(@agent.memory['data']['else'].first.last).to be_within(10).of((100 - 2).hours.ago.to_i)
    end

    it "works without a group_by_path as well" do
      @agent.options['group_by_path'] = ""
      events = build_events(:keys => ['count'], :values => [[1], [2]])
      @agent.receive events
      expect(@agent.memory['data']['no_group'].map(&:first)).to eq([1, 2])
    end

    it "keeps a rolling window of data" do
      @agent.options['window_duration_in_days'] = 5/24.0
      @agent.receive build_events(:keys => ['count'],
                                  :values => [1, 2, 3, 4, 5, 6, 7, 8].map {|i| [i]},
                                  :pattern => { 'filter' => "something" })
      expect(@agent.memory['data']['something'].map(&:first)).to eq([4, 5, 6, 7, 8])
    end

    it "finds peaks" do
      build_events(:keys => ['count'],
                   :values => [5, 6,
                               4, 5,
                               4, 5,
                               15, 11, # peak
                               8, 50, # ignored because it's too close to the first peak
                               4, 5].map {|i| [i]},
                   :pattern => { 'filter' => "something" }).each.with_index do |event, index|
        expect {
          @agent.receive([event])
        }.to change { @agent.events.count }.by( index == 6 ? 1 : 0 )
      end

      expect(@agent.events.last.payload['peak']).to eq(15.0)
      expect(@agent.memory['peaks']['something'].length).to eq(1)
    end

    it "keeps a rolling window of peaks" do
      @agent.options['min_peak_spacing_in_days'] = 1/24.0
      @agent.receive build_events(:keys => ['count'],
                                  :values => [1, 1, 1, 1, 1, 1, 10, 1, 1, 1, 1, 1, 1, 1, 10, 1].map {|i| [i]},
                                  :pattern => { 'filter' => "something" })
      expect(@agent.memory['peaks']['something'].length).to eq(2)
    end
  end

  describe "validation" do
    before do
      expect(@agent).to be_valid
    end

    it "should validate presence of message" do
      @agent.options['message'] = nil
      expect(@agent).not_to be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      @agent.options['expected_receive_period_in_days'] = ""
      expect(@agent).not_to be_valid
    end

    it "should validate presence of value_path" do
      @agent.options['value_path'] = ""
      expect(@agent).not_to be_valid
    end
  end
end
