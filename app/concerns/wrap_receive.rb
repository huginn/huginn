module WrapReceive
  extend ActiveSupport::Concern

  class EventsWrapper < Array
    attr_reader :events, :agent

    def initialize(events, agent)
      @agent = agent
      super(events)
    end

    def each
      super do |event|
        agent.receiving_event(event)
        yield event
      end
    end
  end

  module ReceiveWrapper
    def receive(incoming_events)
      super EventsWrapper.new(incoming_events, self)
    end
  end

  def receiving_event(event)
    @receiving_event = event
  end

  module ClassMethods
    def inherited(subclass)
      super
      subclass.prepend ReceiveWrapper
    end
  end
end
