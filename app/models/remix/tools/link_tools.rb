module Remix
  module Tools
    class ConnectAgents < BaseTool
      def self.tool_name = 'connect_agents'
      def self.description = 'Create event flow link between agents'
      def self.parameters
        {
          type: 'object',
          properties: {
            source_id: { type: 'integer', description: 'ID of source agent (emits events)' },
            receiver_id: { type: 'integer', description: 'ID of receiver agent (receives events)' },
            propagate_immediately: { type: 'boolean', description: 'Propagate events immediately instead of on schedule' }
          },
          required: %w[source_id receiver_id]
        }
      end

      def execute(params)
        source = user.agents.find_by(id: params['source_id'])
        return error_response('Source agent not found') unless source

        receiver = user.agents.find_by(id: params['receiver_id'])
        return error_response('Receiver agent not found') unless receiver

        return error_response("'#{source.name}' cannot create events") unless source.can_create_events?
        return error_response("'#{receiver.name}' cannot receive events") unless receiver.can_receive_events?

        if source.receivers.include?(receiver)
          return error_response("Link already exists between '#{source.name}' and '#{receiver.name}'")
        end

        link = source.links_as_source.build(receiver: receiver)
        
        if link.save
          # Update propagate_immediately if specified
          if params.key?('propagate_immediately')
            source.update(propagate_immediately: params['propagate_immediately'])
          end
          
          success_response("Connected '#{source.name}' → '#{receiver.name}'")
        else
          error_response("Failed to create link", link.errors.full_messages)
        end
      end
    end

    class DisconnectAgents < BaseTool
      def self.tool_name = 'disconnect_agents'
      def self.description = 'Remove event flow link between agents'
      def self.parameters
        {
          type: 'object',
          properties: {
            source_id: { type: 'integer', description: 'ID of source agent' },
            receiver_id: { type: 'integer', description: 'ID of receiver agent' }
          },
          required: %w[source_id receiver_id]
        }
      end

      def execute(params)
        source = user.agents.find_by(id: params['source_id'])
        return error_response('Source agent not found') unless source

        receiver = user.agents.find_by(id: params['receiver_id'])
        return error_response('Receiver agent not found') unless receiver

        link = source.links_as_source.find_by(receiver: receiver)
        return error_response("No link exists between '#{source.name}' and '#{receiver.name}'") unless link

        link.destroy!
        success_response("Disconnected '#{source.name}' → '#{receiver.name}'")
      end
    end

    class AddControlLink < BaseTool
      def self.tool_name = 'add_control_link'
      def self.description = 'Add control relationship (allows one agent to enable/disable another)'
      def self.parameters
        {
          type: 'object',
          properties: {
            controller_id: { type: 'integer', description: 'ID of controlling agent' },
            target_id: { type: 'integer', description: 'ID of target agent to be controlled' }
          },
          required: %w[controller_id target_id]
        }
      end

      def execute(params)
        controller = user.agents.find_by(id: params['controller_id'])
        return error_response('Controller agent not found') unless controller

        target = user.agents.find_by(id: params['target_id'])
        return error_response('Target agent not found') unless target

        return error_response("'#{controller.name}' cannot control other agents") unless controller.can_control_other_agents?

        if controller.control_targets.include?(target)
          return error_response("Control link already exists between '#{controller.name}' and '#{target.name}'")
        end

        link = controller.control_links.build(control_target: target)
        
        if link.save
          success_response("Added control link: '#{controller.name}' controls '#{target.name}'")
        else
          error_response("Failed to create control link", link.errors.full_messages)
        end
      end
    end

    class RemoveControlLink < BaseTool
      def self.tool_name = 'remove_control_link'
      def self.description = 'Remove control relationship'
      def self.parameters
        {
          type: 'object',
          properties: {
            controller_id: { type: 'integer', description: 'ID of controlling agent' },
            target_id: { type: 'integer', description: 'ID of target agent' }
          },
          required: %w[controller_id target_id]
        }
      end

      def execute(params)
        controller = user.agents.find_by(id: params['controller_id'])
        return error_response('Controller agent not found') unless controller

        target = user.agents.find_by(id: params['target_id'])
        return error_response('Target agent not found') unless target

        link = controller.control_links.find_by(control_target: target)
        return error_response("No control link exists between '#{controller.name}' and '#{target.name}'") unless link

        link.destroy!
        success_response("Removed control link: '#{controller.name}' no longer controls '#{target.name}'")
      end
    end
  end
end
