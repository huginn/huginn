require 'spec_helper'

describe Agents::MavenlinkPostAgent do
  subject do
    described_class.new name: 'test' do |agent|
      agent.user = users(:bob)
      agent.save!
    end
  end

  let(:stubbed_request) do
    Faraday::Adapter::Test::Stubs.new do |request|
      request.get('/api/v1/posts') { [200, {}, response.to_json] }
    end
  end

  let(:response) { valid_response }
  let(:invalid_response) { {'invalid_response' => true} }
  let(:valid_response) do
    {
      'count' => 1,
      'results' => [{'key' => 'posts', 'id' => '7'}],
      'posts' => {
        '7' => {'message' => 'Some post', 'id' => '7'}
      }
    }
  end

  before do
    Mavenlink.adapter = [:test, stubbed_request]
  end

  describe '#check' do
    it 'creates new event' do
      expect { subject.check }.to change { subject.most_recent_event(true) }.from(nil).to(Event)
    end

    describe 'most recent event' do
      before { subject.check }

      it 'stores payload data' do
        subject.most_recent_event(true).payload.should include({'id' => '7', 'message' => 'Some post'})
      end
    end

    context 'no new posts' do
      let(:response) do
        {
          'count' => 0,
          'results' => [],
        }
      end

      it 'does nothing' do
        expect { subject.check }.not_to change { subject.most_recent_event(true) }
      end
    end
  end

  describe '#working?' do
    its(:working?) { should eq(true) }

    context 'recently failed' do
      before { described_class.async_check_without_delay(subject.id) rescue subject.reload }

      let(:response) { invalid_response }
      its(:working?) { should eq(false) }

      context 'and restored job' do
        before do
          stubbed_request.get('/api/v1/posts') { [200, {}, valid_response.to_json] }
          subject.check
          subject.reload
        end

        its(:working?) { should eq(true) }
      end
    end
  end

  specify do
    expect(subject.default_options).to have_key('workspace_id')
  end
end