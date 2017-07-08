require 'rails_helper'

describe Agents::CommanderAgent do
  let(:target) {
    agents(:bob_website_agent)
  }

  let(:valid_params) {
    {
      name: 'Example',
      schedule: 'every_1h',
      options: {
        'action' => 'run',
      },
      user: users(:bob),
      control_targets: [target]
    }
  }

  let(:agent) {
    described_class.create!(valid_params)
  }

  it_behaves_like AgentControllerConcern

  describe "check" do
    it "should command targets" do
      stub(Agent).async_check(target.id).once { nil }
      agent.check
    end
  end

  describe "receive_events" do
    it "should command targets" do
      stub(Agent).async_check(target.id).once { nil }

      event = Event.new
      event.agent = agents(:bob_rain_notifier_agent)
      event.payload = {
        'url' => 'http://xkcd.com',
        'link' => 'Random',
      }
      agent.receive([event])
    end

    context "to configure" do
      let(:real_target) {
        Agents::TriggerAgent.create!(
          name: "somename",
          options: {
            expected_receive_period_in_days: 2,
            rules: [
              {
                'type' => 'field<value',
                'value' => '200.0',
                'path' => 'price',
              }
            ],
            keep_event: 'true'
          },
          user: users(:bob)
        )
      }

      let(:valid_params) {
        {
          name: 'Example',
          schedule: 'never',
          options: {
            'action' => '{% if target.id == agent_id %}configure{% endif %}',
            'configure_options' => {
              'rules' => [
                {
                  'type' => 'field<value',
                  'value' => "{{price}}",
                  'path' => 'price',
                }
              ]
            }
          },
          user: users(:bob),
          control_targets: [target, real_target]
        }
      }

      it "should conditionally configure targets interpolating agent attributes" do
        expect {
          event = Event.new
          event.agent = agents(:bob_website_agent)
          event.payload = {
            'price' => '198.0',
            'agent_id' => real_target.id
          }
          agent.receive([event])
        }.to change {
          real_target.options['rules'][0]['value']
        }.from('200.0').to('198.0') & not_change {
          target.options
        }
      end
    end
  end
end
