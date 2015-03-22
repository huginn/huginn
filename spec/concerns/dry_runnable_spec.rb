require 'spec_helper'

describe DryRunnable do
  class Agents::SandboxedAgent < Agent
    default_schedule "3pm"

    can_dry_run!

    def check
      log "Logging"
      create_event payload: { test: "foo" }
      error "Recording error"
      create_event payload: { test: "bar" }
      self.memory = { last_status: "ok" }
      save!
    end
  end

  before do
    stub(Agents::SandboxedAgent).valid_type?("Agents::SandboxedAgent") { true }

    @agent = Agents::SandboxedAgent.create(name: "some agent") { |agent|
      agent.user = users(:bob)
    }
  end

  it "traps logging, event emission and memory updating" do
    results = nil

    expect {
      results = @agent.dry_run!
    }.not_to change {
      [users(:bob).agents.count, users(:bob).events.count, users(:bob).logs.count]
    }

    expect(results[:log]).to match(/\AI, .+ INFO -- : Logging\nE, .+ ERROR -- : Recording error\n/)
    expect(results[:events]).to eq([{ test: 'foo' }, { test: 'bar' }])
    expect(results[:memory]).to eq({ "last_status" => "ok" })
  end

  it "does not perform dry-run if Agent does not support dry-run" do
    stub(@agent).can_dry_run? { false }

    results = nil

    expect {
      results = @agent.dry_run!
    }.not_to change {
      [users(:bob).agents.count, users(:bob).events.count, users(:bob).logs.count]
    }

    expect(results[:log]).to match(/\AE, .+ ERROR -- : Exception during dry-run. SandboxedAgent does not support dry-run: /)
    expect(results[:events]).to eq([])
    expect(results[:memory]).to eq({})
  end
end
