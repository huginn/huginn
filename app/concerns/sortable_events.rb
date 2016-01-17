module SortableEvents
  extend ActiveSupport::Concern

  included do
    validate :validate_events_order
  end

  def description_events_order(*args)
    self.class.description_events_order(*args)
  end

  module ClassMethods
    def can_order_created_events!
      raise 'Cannot order events for agent that cannot create events' if cannot_create_events?
      prepend AutomaticSorter
    end

    def can_order_created_events?
      include? AutomaticSorter
    end

    def cannot_order_created_events?
      !can_order_created_events?
    end

    def description_events_order(events = 'events created in each run')
      <<-MD.lstrip
        To specify the order of #{events}, set `events_order` to an array of sort keys, each of which looks like either `expression` or `[expression, type, descending]`, as described as follows:

        * _expression_ is a Liquid template to generate a string to be used as sort key.

        * _type_ (optional) is one of `string` (default), `number` and `time`, which specifies how to evaluate _expression_ for comparison.

        * _descending_ (optional) is a boolean value to determine if comparison should be done in descending (reverse) order, which defaults to `false`.

        Sort keys listed earlier take precedence over ones listed later.  For example, if you want to sort articles by the date and then by the author, specify `[["{{date}}", "time"], "{{author}}"]`.

        Sorting is done stably, so even if all events have the same set of sort key values the original order is retained.  Also, a special Liquid variable `_index_` is provided, which contains the zero-based index number of each event, which means you can exactly reverse the order of events by specifying `[["{{_index_}}", "number", true]]`.
      MD
    end
  end

  def can_order_created_events?
    self.class.can_order_created_events?
  end

  def cannot_order_created_events?
    self.class.cannot_order_created_events?
  end

  def events_order
    options['events_order']
  end

  module AutomaticSorter
    def check
      return super unless events_order
      sorting_events do
        super
      end
    end

    def receive(incoming_events)
      return super unless events_order
      # incoming events should be processed sequentially
      incoming_events.each do |event|
        sorting_events do
          super([event])
        end
      end
    end

    def create_event(event)
      if @sortable_events
        event = build_event(event)
        @sortable_events << event
        event
      else
        super
      end
    end

    private

    def sorting_events(&block)
      @sortable_events = []
      yield
    ensure
      events, @sortable_events = @sortable_events, nil
      sort_events(events).each do |event|
        create_event(event)
      end
    end
  end

  private

  EXPRESSION_PARSER = {
    'string' => ->string { string },
    'number' => ->string { string.to_f },
    'time'   => ->string { Time.zone.parse(string) },
  }
  EXPRESSION_TYPES = EXPRESSION_PARSER.keys.freeze

  def validate_events_order
    case order_by = events_order
    when nil
    when Array
      # Each tuple may be either [expression, type, desc] or just
      # expression.
      order_by.each do |expression, type, desc|
        case expression
        when String
          # ok
        else
          errors.add(:base, "first element of each events_order tuple must be a Liquid template")
          break
        end
        case type
        when nil, *EXPRESSION_TYPES
          # ok
        else
          errors.add(:base, "second element of each events_order tuple must be #{EXPRESSION_TYPES.to_sentence(last_word_connector: ' or ')}")
          break
        end
        if !desc.nil? && boolify(desc).nil?
          errors.add(:base, "third element of each events_order tuple must be a boolean value")
          break
        end
      end
    else
      errors.add(:base, "events_order must be an array of arrays")
    end
  end

  # Sort given events in order specified by the "events_order" option
  def sort_events(events)
    order_by = events_order.presence or
      return events

    orders = order_by.map { |_, _, desc = false| boolify(desc) }

    Utils.sort_tuples!(
      events.map.with_index { |event, index|
        interpolate_with(event) {
          interpolation_context['_index_'] = index
          order_by.map { |expression, type, _|
            string = interpolate_string(expression)
            begin
              EXPRESSION_PARSER[type || 'string'.freeze][string]
            rescue
              error "Cannot parse #{string.inspect} as #{type}; treating it as string"
              string
            end
          }
        } << index << event  # index is to make sorting stable
      },
      orders
    ).collect!(&:last)
  end
end
