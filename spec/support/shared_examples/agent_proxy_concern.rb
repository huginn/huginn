shared_examples_for AgentProxyConcern do
  before do
    allow(OutboundProxy).to receive(:url).and_return(nil)
    allow(OutboundProxy).to receive(:agent_url).and_return("http://optional-proxy:4750")
  end

  it "does not select AGENT_PROXY by default" do
    expect(agent.request_proxy).to be_nil
    expect(proxy_client.instance_variable_get(:@manual_proxy)).to be_falsey
  end

  [true, "true"].each do |value|
    it "selects AGENT_PROXY with use_agent_proxy=#{value.inspect}" do
      agent.options["use_agent_proxy"] = value
      expect(agent).to be_valid
      expect(proxy_client.proxy.uri.to_s).to eq("http://optional-proxy:4750")
    end
  end

  [false, "false"].each do |value|
    it "does not select AGENT_PROXY with use_agent_proxy=#{value.inspect}" do
      agent.options["use_agent_proxy"] = value
      expect(agent).to be_valid
      expect(agent.request_proxy).to be_nil
    end
  end

  it "rejects an invalid boolean" do
    agent.options["use_agent_proxy"] = "yes"
    expect(agent).not_to be_valid
    expect(agent.errors[:base]).to include("if provided, use_agent_proxy must be true or false")
  end

  it "rejects opt-in without AGENT_PROXY and never falls back to a direct connection" do
    allow(OutboundProxy).to receive(:agent_url).and_return(nil)
    agent.options["use_agent_proxy"] = true
    expect(agent).not_to be_valid
    expect(agent.errors[:base]).to include("use_agent_proxy requires AGENT_PROXY")
    expect { proxy_client }.to raise_error(OutboundProxy::ConfigurationError, "use_agent_proxy requires AGENT_PROXY")
  end

  it "rejects combining opt-in with an explicit proxy" do
    agent.options["use_agent_proxy"] = true
    agent.options["proxy"] = "http://other-proxy:3128"
    expect(agent).not_to be_valid
    expect(agent.errors[:base]).to include("proxy cannot be combined with use_agent_proxy")
  end

  it "continues to support an explicit proxy" do
    agent.options["proxy"] = "http://other-proxy:3128"
    expect(agent).to be_valid
    expect(proxy_client.proxy.uri.to_s).to eq("http://other-proxy:3128")
  end

  [nil, true, false, "true", "false"].each do |value|
    it "enforces OUTBOUND_PROXY with use_agent_proxy=#{value.inspect}" do
      allow(OutboundProxy).to receive(:url).and_return("http://forced-proxy:4750")
      allow(OutboundProxy).to receive(:agent_url).and_return(nil)
      agent.options["use_agent_proxy"] = value
      expect(agent).to be_valid
      expect(proxy_client.proxy.uri.to_s).to eq("http://forced-proxy:4750")
    end
  end

  it "prefers OUTBOUND_PROXY over AGENT_PROXY" do
    allow(OutboundProxy).to receive(:url).and_return("http://forced-proxy:4750")
    agent.options["use_agent_proxy"] = true
    expect(proxy_client.proxy.uri.to_s).to eq("http://forced-proxy:4750")
  end

  it "refuses an explicit proxy and enforces OUTBOUND_PROXY even without validation" do
    allow(OutboundProxy).to receive(:url).and_return("http://forced-proxy:4750")
    agent.options["proxy"] = "http://other-proxy:3128"
    expect(agent).not_to be_valid
    expect(proxy_client.proxy.uri.to_s).to eq("http://forced-proxy:4750")
  end
end
