require 'rails_helper'

describe Agents::DropboxWatchAgent do
  before(:each) do
    @agent = Agents::DropboxWatchAgent.new(
      name: 'save to dropbox',
      options: {
        access_token: '70k3n',
        dir_to_watch: '/my/dropbox/dir',
        expected_update_period_in_days: 2
      }
    )
    @agent.user = users(:bob)
    @agent.service = services(:generic)
    @agent.save!
  end

  it 'cannot receive events' do
    expect(@agent.cannot_receive_events?).to eq true
  end

  it 'has agent description' do
    expect(@agent.description).to_not be_nil
  end

  it 'has event description' do
    expect(@agent.event_description).to_not be_nil
  end

  describe '#valid?' do
    before(:each) { expect(@agent.valid?).to eq true }

    it 'requires a "dir_to_watch"' do
      @agent.options[:dir_to_watch] = nil
      expect(@agent.valid?).to eq false
    end

    describe 'expected_update_period_in_days' do
      it 'needs to be present' do
        @agent.options[:expected_update_period_in_days] = nil
        expect(@agent.valid?).to eq false
      end

      it 'needs to be a positive integer' do
        @agent.options[:expected_update_period_in_days] = -1
        expect(@agent.valid?).to eq false
      end
    end
  end

  describe '#check' do

    let(:first_result) { [{ 'path' => '1.json', 'rev' => '1', 'modified' => '01-01-01' }] }

    before(:each) do
      stub.proxy(Dropbox::API::Client).new do |api|
        stub(api).ls('/my/dropbox/dir') { first_result }
      end
    end

    it 'saves the directory listing in its memory' do
      @agent.check
      expect(@agent.memory).to eq 'contents' => first_result
    end

    context 'first time' do

      before(:each) { @agent.memory = {} }

      it 'does not send any events' do
        expect { @agent.check }.to_not change(Event, :count)
      end

    end

    context 'subsequent calls' do

      let(:second_result) { [{ 'path' => '2.json', 'rev' => '1', 'modified' => '02-02-02' }] }

      before(:each) do
        @agent.memory = { 'contents' => 'not_empty' }

        stub.proxy(Dropbox::API::Client).new do |api|
          stub(api).ls('/my/dropbox/dir') { second_result }
        end
      end

      it 'sends an event upon a different directory listing' do
        payload = { 'diff' => 'object as hash' }
        stub.proxy(Agents::DropboxWatchAgent::DropboxDirDiff).new(@agent.memory['contents'], second_result) do |diff|
          stub(diff).empty? { false }
          stub(diff).to_hash { payload }
        end
        expect { @agent.check }.to change(Event, :count).by(1)
        expect(Event.last.payload).to eq(payload)
      end

      it 'does not sent any events when there is no difference on the directory listing' do
        stub.proxy(Agents::DropboxWatchAgent::DropboxDirDiff).new(@agent.memory['contents'], second_result) do |diff|
          stub(diff).empty? { true }
        end

        expect { @agent.check }.to_not change(Event, :count)
      end

    end
  end

  describe Agents::DropboxWatchAgent::DropboxDirDiff do

    let(:previous) { [
      { 'path' => '1.json', 'rev' => '1' },
      { 'path' => '2.json', 'rev' => '1' },
      { 'path' => '3.json', 'rev' => '1' }
    ] }

    let(:current) { [
      { 'path' => '1.json', 'rev' => '2' },
      { 'path' => '3.json', 'rev' => '1' },
      { 'path' => '4.json', 'rev' => '1' }
    ] }

    describe '#empty?' do

      it 'is true when no differences are detected' do
        diff = Agents::DropboxWatchAgent::DropboxDirDiff.new(previous, previous)
        expect(diff.empty?).to eq true
      end

      it 'is false when differences were detected' do
        diff = Agents::DropboxWatchAgent::DropboxDirDiff.new(previous, current)
        expect(diff.empty?).to eq false
      end

    end

    describe '#to_hash' do

      subject(:diff_hash) { Agents::DropboxWatchAgent::DropboxDirDiff.new(previous, current).to_hash }

      it 'detects additions' do
        expect(diff_hash[:added]).to eq [{ 'path' => '4.json', 'rev' => '1' }]
      end

      it 'detects removals' do
        expect(diff_hash[:removed]).to eq [ { 'path' => '2.json', 'rev' => '1' } ]
      end

      it 'detects updates' do
        expect(diff_hash[:updated]).to eq [ { 'path' => '1.json', 'rev' => '2' } ]
      end

      context 'when the previous value is not defined' do
        it 'considers all additions' do
          diff_hash = Agents::DropboxWatchAgent::DropboxDirDiff.new(nil, current).to_hash
          expect(diff_hash[:added]).to eq current
          expect(diff_hash[:removed]).to eq []
          expect(diff_hash[:updated]).to eq []
        end
      end

      context 'when the current value is not defined' do
        it 'considers all removals' do
          diff_hash = Agents::DropboxWatchAgent::DropboxDirDiff.new(previous, nil).to_hash
          expect(diff_hash[:added]).to eq []
          expect(diff_hash[:removed]).to eq previous
          expect(diff_hash[:updated]).to eq []
        end
      end
    end
  end

end