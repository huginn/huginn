require 'rails_helper'

describe 'Parallel Search MCP scenario' do
  let(:endpoint) { 'https://search.parallel.ai/mcp' }
  let(:session_id) { 'b6cd8fe1-3210-4567-890a-123456789abc' }
  let(:user_agent) { 'Huginn Parallel Search scenario' }

  before do
    importer = ScenarioImport.new(data: File.read(Rails.root.join('data/parallel_search_scenario.json')))
    importer.set_user(users(:jane))
    expect(importer).to be_valid
    expect(importer.import).to be(true), importer.errors.full_messages.join(', ')
    @scenario = importer.scenario
    @requests = []
    @initialize_status = 200
    @notification_status = 202
    @session_header = session_id
    @protocol_version = '2025-03-26'
    stub_request(:post, endpoint).to_return do |request|
      @requests << request
      rpc = JSON.parse(request.body)
      case rpc['method']
      when 'initialize'
        { status: @initialize_status,
          headers: { 'Content-Type' => 'application/json', 'Mcp-Session-Id' => @session_header },
          body: { jsonrpc: '2.0', id: 1, result: { protocolVersion: @protocol_version } }.to_json }
      when 'notifications/initialized'
        { status: @notification_status, body: '' }
      when 'tools/call'
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: { jsonrpc: '2.0', id: rpc['id'], result: {
            content: [{ type: 'text', text: 'Huginn documentation https://github.com/huginn/huginn' }],
            isError: false
          } }.to_json }
      else
        raise "Unexpected RPC method: #{rpc['method']}"
      end
    end
  end

  # Follow the imported links and execute the real Agent implementations.
  def run_scenario(payload)
    input = @scenario.agents.find_by!(name: 'Parallel request')
    expect(input.handle_details_post('payload' => payload.to_json)).to eq(success: true)
    queue = [[input, input.events.order(:id).last]]
    until queue.empty?
      source, event = queue.shift
      source.receivers.order(:id).each do |receiver|
        previous_id = receiver.events.maximum(:id) || 0
        receiver.receive([event])
        receiver.events.where('id > ?', previous_id).order(:id).each do |output|
          queue << [receiver, output]
        end
      end
    end
  end

  def rpc_requests
    @requests.map { |request| JSON.parse(request.body) }
  end

  it 'imports valid Agents without adding credentials or scheduled requests' do
    expect(@scenario.agents.count).to eq(9)
    expect(@scenario.agents).to all(be_valid)
    expect(@scenario.agents.where(type: 'Agents::PostAgent').pluck(:schedule).uniq).to eq(['never'])
    expect(@scenario.agents.pluck(:options).to_json).not_to match(/api_key|authorization|credential/i)
  end

  it 'searches through the imported graph with escaped input and the initialized session' do
    query = 'Huginn "new Agents" \\ docs'
    run_scenario('operation' => 'search', 'objective' => 'Find official docs', 'query' => query)
    expect(rpc_requests.map { |rpc| rpc['method'] }).to eq(%w[initialize notifications/initialized tools/call])
    expect(rpc_requests.last['params']).to eq('name' => 'web_search', 'arguments' => {
      'objective' => 'Find official docs', 'search_queries' => [query], 'session_id' => session_id
    })
    @requests.each do |request|
      expect([request.uri.scheme, request.uri.host, request.uri.port, request.uri.path]).to eq(
        ['https', 'search.parallel.ai', 443, '/mcp']
      )
      expect(request.headers['User-Agent']).to eq(user_agent)
      expect(request.headers['Accept']).to eq('application/json, text/event-stream')
      expect(request.headers.keys).not_to include('Authorization', 'X-Api-Key')
    end
    @requests.drop(1).each do |request|
      expect(request.headers['Mcp-Session-Id']).to eq(session_id)
      expect(request.headers['Mcp-Protocol-Version']).to eq('2025-03-26')
    end
    output = @scenario.agents.find_by!(name: 'Parallel web search').events.last.payload
    expect(output['status']).to eq(200)
    expect(output.dig('body', 'result', 'content', 0, 'text')).to include('Huginn documentation')
    expect(output['query']).to eq(query)
    expect(@scenario.agents.find_by!(name: 'Parallel page fetch').events).to be_empty
  end

  it 'fetches only the requested page' do
    url = 'https://github.com/huginn/huginn'
    run_scenario('operation' => 'fetch', 'url' => url)
    expect(rpc_requests.last['params']).to eq('name' => 'web_fetch', 'arguments' => {
      'urls' => [url], 'session_id' => session_id
    })
    expect(@scenario.agents.find_by!(name: 'Parallel page fetch').events.last.payload.dig('body', 'result', 'isError')).to be(false)
    expect(@scenario.agents.find_by!(name: 'Parallel web search').events).to be_empty
  end

  it 'stops when initialization fails' do
    @initialize_status = 429
    run_scenario('operation' => 'search', 'query' => 'Huginn', 'objective' => 'Find docs')
    expect(rpc_requests.map { |rpc| rpc['method'] }).to eq(['initialize'])
  end

  it 'stops when the session header is missing' do
    @session_header = ''
    run_scenario('operation' => 'search')
    expect(rpc_requests.map { |rpc| rpc['method'] }).to eq(['initialize'])
  end

  it 'stops when the negotiated protocol differs' do
    @protocol_version = '2024-11-05'
    run_scenario('operation' => 'search')
    expect(rpc_requests.map { |rpc| rpc['method'] }).to eq(['initialize'])
  end

  it 'does not dispatch a tool after an unsuccessful notification' do
    @notification_status = 400
    run_scenario('operation' => 'search')
    expect(rpc_requests.map { |rpc| rpc['method'] }).to eq(%w[initialize notifications/initialized])
  end

  it 'does not dispatch an unknown operation' do
    run_scenario('operation' => 'other')
    expect(rpc_requests.map { |rpc| rpc['method'] }).to eq(%w[initialize notifications/initialized])
  end
end
