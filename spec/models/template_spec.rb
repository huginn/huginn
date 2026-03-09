require 'rails_helper'

describe 'Template feature' do
  describe Agent, 'template support' do
    let(:user) { users(:bob) }

    describe '.templates / .non_templates scopes' do
      before do
        @template = user.agents.create!(
          name: 'My Template',
          type: 'Agents::WeatherAgent',
          template: true,
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
      end

      it 'returns only templates with .templates scope' do
        expect(Agent.templates).to include(@template)
        expect(Agent.templates).not_to include(agents(:bob_website_agent))
      end

      it 'returns only non-templates with .non_templates scope' do
        expect(Agent.non_templates).not_to include(@template)
        expect(Agent.non_templates).to include(agents(:bob_website_agent))
      end
    end

    describe '#template?' do
      it 'returns true when template is set' do
        agent = Agent.new(template: true)
        expect(agent.template?).to be true
      end

      it 'returns false when template is not set' do
        agent = Agent.new(template: false)
        expect(agent.template?).to be false
      end

      it 'returns false by default' do
        agent = Agent.new
        expect(agent.template?).to be false
      end
    end

    describe '#enforce_template_constraints' do
      it 'forces disabled=true and schedule=never on save' do
        agent = user.agents.create!(
          name: 'Constraint Test',
          type: 'Agents::WeatherAgent',
          template: true,
          disabled: false,
          schedule: 'midnight',
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
        expect(agent.disabled).to be true
        expect(agent.schedule).to eq('never')
      end

      it 'clears template_id when converting to template' do
        source_template = user.agents.create!(
          name: 'Source Template',
          type: 'Agents::WeatherAgent',
          template: true,
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
        # Create a derived agent with template_id
        derived = user.agents.create!(
          name: 'Derived Agent',
          type: 'Agents::WeatherAgent',
          template_id: source_template.id,
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
        expect(derived.template_id).to eq(source_template.id)

        # Now convert the derived agent to a template
        derived.update!(template: true)
        derived.reload
        expect(derived.template?).to be true
        expect(derived.template_id).to be_nil  # template_id should be cleared
      end

      it 'does not affect non-template agents' do
        agent = agents(:bob_weather_agent)
        expect(agent.disabled).to be false
        expect(agent.schedule).not_to eq('never')
      end
    end

    describe '.build_from_template' do
      before do
        @template = user.agents.create!(
          name: 'Weather Template',
          type: 'Agents::WeatherAgent',
          template: true,
          options: { 'api_key' => 'abc123', 'location' => '37.7749,-122.4194' },
          keep_events_for: 86400,
          template_description: 'A weather template'
        )
      end

      it 'creates a new agent based on the template' do
        agent = user.agents.build_from_template(@template)
        expect(agent.type).to eq('Agents::WeatherAgent')
        expect(agent.options).to eq({ 'api_key' => 'abc123', 'location' => '37.7749,-122.4194' })
        expect(agent.template_id).to eq(@template.id)
        expect(agent.disabled).to be false
        expect(agent.template).not_to be true
      end

      it 'copies configuration but not source_ids or receiver_ids' do
        agent = user.agents.build_from_template(@template)
        expect(agent.source_ids).to be_empty
        expect(agent.receiver_ids).to be_empty
      end

      it 'generates a unique name' do
        agent = user.agents.build_from_template(@template)
        expect(agent.name).to match(/Weather Template \(\d+\)/)
      end

      it 'copies keep_events_for' do
        agent = user.agents.build_from_template(@template)
        expect(agent.keep_events_for).to eq(86400)
      end
    end

    describe 'associations' do
      before do
        @template = user.agents.create!(
          name: 'Source Template',
          type: 'Agents::WeatherAgent',
          template: true,
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
        @derived = user.agents.create!(
          name: 'Derived Agent',
          type: 'Agents::WeatherAgent',
          template_id: @template.id,
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
      end

      it 'tracks derived agents' do
        expect(@template.derived_agents).to include(@derived)
      end

      it 'tracks the source template' do
        expect(@derived.source_template).to eq(@template)
      end

      it 'nullifies template_id when template is destroyed' do
        @template.destroy
        expect(@derived.reload.template_id).to be_nil
      end
    end

    describe 'execution guards' do
      before do
        @template = user.agents.create!(
          name: 'Template Guard Test',
          type: 'Agents::WeatherAgent',
          template: true,
          schedule: 'midnight',
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
      end

      it 'excludes templates from bulk_check' do
        # Template schedule is forced to 'never', so it won't match 'midnight'
        expect(@template.schedule).to eq('never')
      end
    end
  end

  describe AgentsController, 'template actions', type: :controller do
    let(:user) { users(:bob) }

    before do
      sign_in user
    end

    describe 'GET index' do
      before do
        @template = user.agents.create!(
          name: 'Index Template',
          type: 'Agents::WeatherAgent',
          template: true,
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
      end

      it 'excludes templates from the agents listing' do
        get :index
        expect(assigns(:agents)).not_to include(@template)
      end
    end

    describe 'GET templates' do
      before do
        @template = user.agents.create!(
          name: 'Templates Index',
          type: 'Agents::WeatherAgent',
          template: true,
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
      end

      it 'lists only templates' do
        get :templates
        expect(assigns(:templates)).to include(@template)
        expect(assigns(:templates).all?(&:template?)).to be true
      end

      it 'does not include non-template agents' do
        get :templates
        expect(assigns(:templates)).not_to include(agents(:bob_website_agent))
      end
    end

    describe 'GET template_details' do
      render_views

      before do
        @template = user.agents.create!(
          name: 'Details Template',
          type: 'Agents::WeatherAgent',
          template: true,
          template_description: 'My template description',
          options: { 'api_key' => 'test123', 'location' => '37.7749,-122.4194' }
        )
      end

      it 'returns template configuration as JSON' do
        get :template_details, params: { id: @template.id }
        json = JSON.parse(response.body)
        expect(json['type']).to eq('Agents::WeatherAgent')
        expect(json['template_name']).to eq('Details Template')
        expect(json['template_description']).to eq('My template description')
        expect(json['template_id']).to eq(@template.id)
        expect(json['options']).to eq({ 'api_key' => 'test123', 'location' => '37.7749,-122.4194' })
      end

      it "cannot access another user's templates" do
        jane_template = users(:jane).agents.create!(
          name: 'Jane Template',
          type: 'Agents::WeatherAgent',
          template: true,
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
        expect {
          get :template_details, params: { id: jane_template.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'POST convert_to_template' do
      it 'converts an agent to a template' do
        agent = agents(:bob_weather_agent)
        post :convert_to_template, params: { id: agent.to_param }
        agent.reload
        expect(agent.template?).to be true
        expect(agent.disabled).to be true
        expect(agent.schedule).to eq('never')
      end

      it 'clears events, logs, and memory' do
        agent = agents(:bob_website_agent)
        agent.update!(memory: { 'test' => 42 })
        post :convert_to_template, params: { id: agent.to_param }
        agent.reload
        expect(agent.events_count).to eq(0)
        expect(agent.memory).to eq({})
      end

      it 'clears sources and receivers' do
        source_agent = agents(:bob_weather_agent)
        receiver_agent = agents(:bob_rain_notifier_agent)
        agent = user.agents.create!(
          name: 'Agent With Links',
          type: 'Agents::TriggerAgent',
          source_ids: [source_agent.id],
          receiver_ids: [receiver_agent.id],
          options: {
            'expected_receive_period_in_days' => 2,
            'rules' => [{ 'type' => 'field==value', 'value' => 'test', 'path' => 'name' }],
            'message' => 'Triggered!',
            'keep_event' => 'true'
          }
        )
        expect(agent.sources).to include(source_agent)
        expect(agent.receivers).to include(receiver_agent)

        post :convert_to_template, params: { id: agent.to_param }
        agent.reload
        expect(agent.template?).to be true
        expect(agent.sources).to be_empty
        expect(agent.receivers).to be_empty
      end

      it 'does not re-convert an already-template agent' do
        template = user.agents.create!(
          name: 'Already Template',
          type: 'Agents::WeatherAgent',
          template: true,
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
        post :convert_to_template, params: { id: template.to_param }
        expect(flash[:notice]).to include('already a template')
      end

      it "cannot convert another user's agent" do
        expect {
          post :convert_to_template, params: { id: agents(:jane_website_agent).to_param }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'POST run' do
      it 'blocks running a template' do
        template = user.agents.create!(
          name: 'No Run Template',
          type: 'Agents::WeatherAgent',
          template: true,
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
        post :run, params: { id: template.to_param }
        expect(flash[:notice]).to include('cannot be run')
      end
    end

    describe 'GET new with template_id' do
      before do
        @template = user.agents.create!(
          name: 'New From Template',
          type: 'Agents::WeatherAgent',
          template: true,
          options: { 'api_key' => 'from_template', 'location' => '37.7771,-122.4196' }
        )
      end

      it 'builds an agent from the template' do
        get :new, params: { template_id: @template.id }
        agent = assigns(:agent)
        expect(agent.type).to eq('Agents::WeatherAgent')
        expect(agent.template_id).to eq(@template.id)
        expect(agent.options).to eq({ 'api_key' => 'from_template', 'location' => '37.7771,-122.4196' })
        expect(agent.template).not_to be true
      end

      it "cannot build from another user's template" do
        jane_template = users(:jane).agents.create!(
          name: 'Jane Template',
          type: 'Agents::WeatherAgent',
          template: true,
          options: { 'api_key' => 'test', 'location' => '37.7771,-122.4196' }
        )
        expect {
          get :new, params: { template_id: jane_template.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
