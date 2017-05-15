require 'rails_helper'
require 'ostruct'

describe Agents::ChattermillResponseAgent do
  let(:segments) do
    { 'segment_id' => { 'type' => 'text', 'name' => 'Segment Id', 'value' => '{{data.segment}}' } }
  end

  let(:user_meta) do
    { 'meta_id' => { 'type' => 'text', 'name' => 'Meta Id' } }
  end

  before do
    stub.proxy(ENV).[](anything)
    stub(ENV).[]('CHATTERMILL_AUTH_TOKEN') { 'token-123' }

    @valid_options = {
      'organization_subdomain' => 'foo',
      'expected_receive_period_in_days' => 1,
      'comment' => '{{ data.comment }}',
      'segments' => segments.to_json,
      'user_meta' => user_meta.to_json,
      'extra_fields' => '{}'
    }
    @valid_params = {
      name: "somename",
      options: @valid_options
    }

    @checker = Agents::ChattermillResponseAgent.new(@valid_params)
    @checker.user = users(:jane)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:jane_weather_agent)
    @event.payload = {
      'somekey' => 'somevalue',
      'data' => {
        'comment' => 'Test Comment'
      }
    }
    @requests = 0
    @sent_requests = Hash.new { |hash, method| hash[method] = [] }

    stub_request(:any, /:/).to_return { |request|
      method = request.method
      @requests += 1
      @sent_requests[method] << req = OpenStruct.new(uri: request.uri, headers: request.headers)
      req.data = ActiveSupport::JSON.decode(request.body)
      if request.headers['Authorization'] =~ /invalid/
        { status: 401, body: '{"error": "Unauthorized"}', headers: { 'Content-type' => 'application/json' } }
      else
        { status: 201, body: '{}', headers: { 'Content-type' => 'application/json' } }
      end
    }
  end

  it_behaves_like WebRequestConcern

  it 'renders the description markdown without errors' do
    expect { @checker.description }.not_to raise_error
  end

  describe "making requests" do
    it "makes POST requests" do
      expect(@checker).to be_valid
      @checker.check
      expect(@requests).to eq(1)
      expect(@sent_requests[:post].length).to eq(1)
    end

    it "uses the correct URI" do
      @checker.check
      uri = @sent_requests[:post].first.uri.to_s
      expect(uri).to eq("http://foo.localhost:3000/webhooks/responses")
    end

    it "generates the authorization header" do
      @checker.check
      auth_header = @sent_requests[:post].first.headers['Authorization']
      expect(auth_header).to eq("Bearer token-123")
    end
  end

  describe "#receive" do
    it "can handle multiple events" do
      event1 = Event.new
      event1.agent = agents(:bob_weather_agent)
      event1.payload = {
        'xyz' => 'value1',
        'data' => {
          'segment' => 'My Segment'
        }
      }

      expect {
        @checker.receive([@event, event1])
      }.to change { @sent_requests[:post].length }.by(2)

      expected = {
        'comment' => 'Test Comment',
        'segments' => { 'segment_id' => { 'type' => 'text', 'name' => 'Segment Id', 'value' => '' } },
        'user_meta' => user_meta
      }
      expect(@sent_requests[:post][0].data).to eq(expected)

      expected = {
        'comment' => '',
        'segments' => { 'segment_id' => { 'type' => 'text', 'name' => 'Segment Id', 'value' => 'My Segment' } },
        'user_meta' => user_meta
      }
      expect(@sent_requests[:post][1].data).to eq(expected)
    end
  end

  describe "#check" do
    it "sends data as a POST request" do
      expect {
        @checker.check
      }.to change { @sent_requests[:post].length }.by(1)

      expected = {
        'comment' => '',
        'segments' => { 'segment_id' => { 'type' => 'text', 'name' => 'Segment Id', 'value' => '' } },
        'user_meta' => user_meta
      }
      expect(@sent_requests[:post][0].data).to eq(expected)
    end

    describe "emitting events" do
      context "when emit_events is not set to true" do
        it "does not emit events" do
          expect {
            @checker.check
          }.not_to change { @checker.events.count }
        end
      end

      context "when emit_events is set to true" do
        before do
          @checker.options['emit_events'] = 'true'
        end

        it "emits the response status" do
          expect {
            @checker.check
          }.to change { @checker.events.count }.by(1)
          expect(@checker.events.last.payload['status']).to eq 201
        end

        it "emits the body" do
          @checker.check
          expect(@checker.events.last.payload['body']).to eq '{}'
        end

        it "emits the response headers capitalized by default" do
          @checker.check
          expect(@checker.events.last.payload['headers']).to eq({ 'Content-Type' => 'application/json' })
        end
      end
    end

    describe "slack notification" do
      before do
        stub(ENV).[]('CHATTERMILL_AUTH_TOKEN') { 'invalid' }
        stub(ENV).[]('SLACK_WEBHOOK_URL') { 'http://slack.webhook/abc' }
        stub(ENV).[]('SLACK_CHANNEL') { '#mychannel' }
      end

      it "sends a slack notification" do
        slack = mock
        mock(slack).ping(/Unauthorized/, { icon_emoji: ':fire:', channel: '#mychannel' }) { true }
        mock(Slack::Notifier).new('http://slack.webhook/abc', { username: 'Huginn' }) { slack }
        @checker.check
      end
    end
  end

  describe "#working?" do
    it "checks if events have been received within expected receive period" do
      expect(@checker).not_to be_working
      described_class.async_receive @checker.id, [@event.id]
      expect(@checker.reload).to be_working
      two_days_from_now = 2.days.from_now
      stub(Time).now { two_days_from_now }
      expect(@checker.reload).not_to be_working
    end
  end

  describe "validation" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate presence of post_url" do
      @checker.options['organization_subdomain'] = ""
      expect(@checker).not_to be_valid
    end

    it "should validate presence of expected_receive_period_in_days" do
      @checker.options['expected_receive_period_in_days'] = ""
      expect(@checker).not_to be_valid
    end

    it "should validate segments as a hash" do
      @checker.options['segments'] = {}
      @checker.save
      expect(@checker).to be_valid
    end

    it "should validate segments as a JSON string" do
      @checker.options['segments'] = segments.to_json
      @checker.save
      expect(@checker).to be_valid

      @checker.options['segments'] = "invalid json"
      @checker.save
      expect(@checker).to_not be_valid
    end

    it "should validate user_meta as a hash" do
      @checker.options['user_meta'] = {}
      @checker.save
      expect(@checker).to be_valid
    end

    it "should validate user_meta as a JSON string" do
      @checker.options['user_meta'] = segments.to_json
      @checker.save
      expect(@checker).to be_valid

      @checker.options['user_meta'] = "invalid json"
      @checker.save
      expect(@checker).to_not be_valid
    end

    it "should validate extra_fields as a hash" do
      @checker.options['extra_fields'] = {}
      @checker.save
      expect(@checker).to be_valid
    end

    it "should validate extra_fields as a JSON string" do
      @checker.options['extra_fields'] = '{}'
      @checker.save
      expect(@checker).to be_valid

      @checker.options['extra_fields'] = "invalid json"
      @checker.save
      expect(@checker).to_not be_valid
    end

    it "requires emit_events to be true or false" do
      @checker.options['emit_events'] = 'what?'
      expect(@checker).not_to be_valid

      @checker.options.delete('emit_events')
      expect(@checker).to be_valid

      @checker.options['emit_events'] = 'true'
      expect(@checker).to be_valid

      @checker.options['emit_events'] = 'false'
      expect(@checker).to be_valid

      @checker.options['emit_events'] = true
      expect(@checker).to be_valid
    end
  end
end
