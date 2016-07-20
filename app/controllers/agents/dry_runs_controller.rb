module Agents
  class DryRunsController < ApplicationController
    include ActionView::Helpers::TextHelper

    def index
      if params[:user]
        if current_user.admin?
          @agent_user = User.find_by!(username: params[:user])
        else
          render(text: 'unauthorized', status: 403) and return
        end
      else
        @agent_user = current_user
      end

      @events = if params[:agent_id]
                  @agent_user.agents.find_by(id: params[:agent_id]).received_events.limit(5)
                elsif params[:source_ids]
                  Event.where(agent_id: @agent_user.agents.where(id: params[:source_ids]).pluck(:id))
                       .order("id DESC").limit(5)
                end

      render layout: false
    end

    def create
      if params[:user]
        if current_user.admin?
          @agent_user = User.find_by!(username: params[:user])
        else
          render(text: 'unauthorized', status: 403) and return
        end
      else
        @agent_user = current_user
      end

      attrs = params[:agent] || {}
      if agent = @agent_user.agents.find_by(id: params[:agent_id])
        # POST /agents/:id/dry_run
        if attrs.present?
          attrs.merge!(memory: agent.memory)
          type = agent.type
          agent = Agent.build_for_type(type, @agent_user, attrs)
        end
      else
        # POST /agents/dry_run
        type = attrs.delete(:type)
        agent = Agent.build_for_type(type, @agent_user, attrs)
      end
      agent.name ||= '(Untitled)'

      if agent.valid?
        if event_payload = params[:event]
          dummy_agent = Agent.build_for_type('ManualEventAgent', @agent_user, name: 'Dry-Runner')
          dummy_agent.readonly!
          event = dummy_agent.events.build(user: @agent_user, payload: event_payload)
        end

        @results = agent.dry_run!(event)
      else
        @results = { events: [], memory: [],
                     log:  [
                       "#{pluralize(agent.errors.count, "error")} prohibited this Agent from being saved:",
                       *agent.errors.full_messages
                     ].join("\n- ") }
      end

      render layout: false
    end
  end
end