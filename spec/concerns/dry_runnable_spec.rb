require 'spec_helper'

describe DryRunnable do
  class Agents::SandboxedAgent < Agent
    default_schedule "3pm"

    can_dry_run!

    def check
      log "Logging"
      create_event payload: { 'test' => 'foo' }
      error "Recording error"
      create_event payload: { 'test' => 'bar' }
      self.memory = { 'last_status' => 'ok', 'dry_run' => dry_run? }
      save!
    end
  end

  before do
    stub(Agents::SandboxedAgent).valid_type?("Agents::SandboxedAgent") { true }

    @agent = Agents::SandboxedAgent.create(name: "some agent") { |agent|
      agent.user = users(:bob)
    }
  end

  def counts
    [users(:bob).agents.count, users(:bob).events.count, users(:bob).logs.count]
  end

  it "does not affect normal run, with dry_run? returning false" do
    before = counts
    after  = before.zip([0, 2, 2]).map { |x, d| x + d }

    expect {
      @agent.check
      @agent.reload
    }.to change { counts }.from(before).to(after)

    expect(@agent.memory).to eq({ 'last_status' => 'ok', 'dry_run' => false })

    payloads = @agent.events.reorder(:id).last(2).map(&:payload)
    expect(payloads).to eq([{ 'test' => 'foo' }, { 'test' => 'bar' }])

    messages = @agent.logs.reorder(:id).last(2).map(&:message)
    expect(messages).to eq(['Logging', 'Recording error'])
  end

  it "traps logging, event emission and memory updating, with dry_run? returning true" do
    results = nil

    expect {
      results = @agent.dry_run!
      @agent.reload
    }.not_to change {
      [@agent.memory, counts]
    }

    expect(results[:log]).to match(/\AI, .+ INFO -- : Logging\nE, .+ ERROR -- : Recording error\n/)
    expect(results[:events]).to eq([{ 'test' => 'foo' }, { 'test' => 'bar' }])
    expect(results[:memory]).to eq({ 'last_status' => 'ok', 'dry_run' => true })
  end

  it "does not perform dry-run if Agent does not support dry-run" do
    stub(@agent).can_dry_run? { false }

    results = nil

    expect {
      results = @agent.dry_run!
      @agent.reload
    }.not_to change {
      [@agent.memory, counts]
    }

    expect(results[:log]).to match(/\AE, .+ ERROR -- : Exception during dry-run. SandboxedAgent does not support dry-run: /)
    expect(results[:events]).to eq([])
    expect(results[:memory]).to eq({})
  end
end
