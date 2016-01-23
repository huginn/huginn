require 'rails_helper'

describe Agents::ManualEventAgent do
  before do
    @checker = Agents::ManualEventAgent.new(name: "My Manual Event Agent")
    @checker.user = users(:jane)
    @checker.save!
  end

  describe "#handle_details_post" do
    it "emits an event with the given payload" do
      expect {
        json = { 'foo' => "bar" }.to_json
        expect(@checker.handle_details_post({ 'payload' => json })).to eq({ success: true })
      }.to change { @checker.events.count }.by(1)
      expect(@checker.events.last.payload).to eq({ 'foo' => 'bar' })
    end

    it "emits multiple events when given a magic 'payloads' key" do
      expect {
        json = { 'payloads' => [{ 'key' => 'value1' }, { 'key' => 'value2' }] }.to_json
        expect(@checker.handle_details_post({ 'payload' => json })).to eq({ success: true })
      }.to change { @checker.events.count }.by(2)
      events = @checker.events.order('id desc')
      expect(events[0].payload).to eq({ 'key' => 'value2' })
      expect(events[1].payload).to eq({ 'key' => 'value1' })
    end

    it "supports Liquid formatting" do
      expect {
        json = { 'key' => "{{ 'now' | date: '%Y' }}", 'nested' => { 'lowercase' => "{{ 'uppercase' | upcase }}" } }.to_json
        expect(@checker.handle_details_post({ 'payload' => json })).to eq({ success: true })
      }.to change { @checker.events.count }.by(1)
      expect(@checker.events.last.payload).to eq({ 'key' => Time.now.year.to_s, 'nested' => { 'lowercase' => 'UPPERCASE' } })
    end

    it "errors when not given a JSON payload" do
      expect {
        expect(@checker.handle_details_post({ 'foo' =>'bar' })).to eq({ success: false, error: "You must provide a JSON payload" })
      }.not_to change { @checker.events.count }
    end
  end
end
