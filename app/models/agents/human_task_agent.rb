module Agents
  class HumanTaskAgent < Agent
    default_schedule "every_10m"

    gem_dependency_check { defined?(RTurk) }

    description <<-MD
      The Human Task Agent is used to create Human Intelligence Tasks (HITs) on Mechanical Turk.

      #{'## Include `rturk` in your Gemfile to use this Agent!' if dependencies_missing?}

      HITs can be created in response to events, or on a schedule.  Set `trigger_on` to either `schedule` or `event`.

      # Schedule

      The schedule of this Agent is how often it should check for completed HITs, __NOT__ how often to submit one.  To configure how often a new HIT
      should be submitted when in `schedule` mode, set `submission_period` to a number of hours.

      # Example

      If created with an event, all HIT fields can contain interpolated values via [liquid templating](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid).
      For example, if the incoming event was a Twitter event, you could make a HITT to rate its sentiment like this:

          {
            "expected_receive_period_in_days": 2,
            "trigger_on": "event",
            "hit": {
              "assignments": 1,
              "title": "Sentiment evaluation",
              "description": "Please rate the sentiment of this message: '{{message}}'",
              "reward": 0.05,
              "lifetime_in_seconds": "3600",
              "questions": [
                {
                  "type": "selection",
                  "key": "sentiment",
                  "name": "Sentiment",
                  "required": "true",
                  "question": "Please select the best sentiment value:",
                  "selections": [
                    { "key": "happy", "text": "Happy" },
                    { "key": "sad", "text": "Sad" },
                    { "key": "neutral", "text": "Neutral" }
                  ]
                },
                {
                  "type": "free_text",
                  "key": "feedback",
                  "name": "Have any feedback for us?",
                  "required": "false",
                  "question": "Feedback",
                  "default": "Type here...",
                  "min_length": "2",
                  "max_length": "2000"
                }
              ]
            }
          }

      As you can see, you configure the created HIT with the `hit` option.  Required fields are `title`, which is the
      title of the created HIT, `description`, which is the description of the HIT, and `questions` which is an array of
      questions.  Questions can be of `type` _selection_ or _free\\_text_.  Both types require the `key`, `name`, `required`,
      `type`, and `question` configuration options.  Additionally, _selection_ requires a `selections` array of options, each of
      which contain `key` and `text`.  For _free\\_text_, the special configuration options are all optional, and are
      `default`, `min_length`, and `max_length`.

      By default, all answers are emitted in a single event.  If you'd like separate events for each answer, set `separate_answers` to `true`.

      # Combining answers

      There are a couple of ways to combine HITs that have multiple `assignments`, all of which involve setting `combination_mode` at the top level.

      ## Taking the majority

      Option 1: if all of your `questions` are of `type` _selection_, you can set `combination_mode` to `take_majority`.
      This will cause the Agent to automatically select the majority vote for each question across all `assignments` and return it as `majority_answer`.
      If all selections are numeric, an `average_answer` will also be generated.

      Option 2: you can have the Agent ask additional human workers to rank the `assignments` and return the most highly ranked answer.
      To do this, set `combination_mode` to `poll` and provide a `poll_options` object.  Here is an example:

          {
            "trigger_on": "schedule",
            "submission_period": 12,
            "combination_mode": "poll",
            "poll_options": {
              "title": "Take a poll about some jokes",
              "instructions": "Please rank these jokes from most funny (5) to least funny (1)",
              "assignments": 3,
              "row_template": "{{joke}}"
            },
            "hit": {
              "assignments": 5,
              "title": "Tell a joke",
              "description": "Please tell me a joke",
              "reward": 0.05,
              "lifetime_in_seconds": "3600",
              "questions": [
                {
                  "type": "free_text",
                  "key": "joke",
                  "name": "Your joke",
                  "required": "true",
                  "question": "Joke",
                  "min_length": "2",
                  "max_length": "2000"
                }
              ]
            }
          }

      Resulting events will have the original `answers`, as well as the `poll` results, and a field called `best_answer` that contains the best answer as determined by the poll.  (Note that `separate_answers` won't work when doing a poll.)

      # Other settings

      `lifetime_in_seconds` is the number of seconds a HIT is left on Amazon before it's automatically closed.  The default is 1 day.

      As with most Agents, `expected_receive_period_in_days` is required if `trigger_on` is set to `event`.
    MD

    event_description <<-MD
      Events look like:

          {
            "answers": [
              {
                "feedback": "Hello!",
                "sentiment": "happy"
              }
            ]
          }
    MD

    def validate_options
      options['hit'] ||= {}
      options['hit']['questions'] ||= []

      errors.add(:base, "'trigger_on' must be one of 'schedule' or 'event'") unless %w[schedule event].include?(options['trigger_on'])
      errors.add(:base, "'hit.assignments' should specify the number of HIT assignments to create") unless options['hit']['assignments'].present? && options['hit']['assignments'].to_i > 0
      errors.add(:base, "'hit.title' must be provided") unless options['hit']['title'].present?
      errors.add(:base, "'hit.description' must be provided") unless options['hit']['description'].present?
      errors.add(:base, "'hit.questions' must be provided") unless options['hit']['questions'].present? && options['hit']['questions'].length > 0

      if options['trigger_on'] == "event"
        errors.add(:base, "'expected_receive_period_in_days' is required when 'trigger_on' is set to 'event'") unless options['expected_receive_period_in_days'].present?
      elsif options['trigger_on'] == "schedule"
        errors.add(:base, "'submission_period' must be set to a positive number of hours when 'trigger_on' is set to 'schedule'") unless options['submission_period'].present? && options['submission_period'].to_i > 0
      end

      if options['hit']['questions'].any? { |question| %w[key name required type question].any? {|k| !question[k].present? } }
        errors.add(:base, "all questions must set 'key', 'name', 'required', 'type', and 'question'")
      end

      if options['hit']['questions'].any? { |question| question['type'] == "selection" && (!question['selections'].present? || question['selections'].length == 0 || !question['selections'].all? {|s| s['key'].present? } || !question['selections'].all? { |s| s['text'].present? })}
        errors.add(:base, "all questions of type 'selection' must have a selections array with selections that set 'key' and 'name'")
      end

      if take_majority? && options['hit']['questions'].any? { |question| question['type'] != "selection" }
        errors.add(:base, "all questions must be of type 'selection' to use the 'take_majority' option")
      end

      if create_poll?
        errors.add(:base, "poll_options is required when combination_mode is set to 'poll' and must have the keys 'title', 'instructions', 'row_template', and 'assignments'") unless options['poll_options'].is_a?(Hash) && options['poll_options']['title'].present? && options['poll_options']['instructions'].present? && options['poll_options']['row_template'].present? && options['poll_options']['assignments'].to_i > 0
      end
    end

    def default_options
      {
        'expected_receive_period_in_days' => 2,
        'trigger_on' => "event",
        'hit' =>
          {
            'assignments' => 1,
            'title' => "Sentiment evaluation",
            'description' => "Please rate the sentiment of this message: '{{message}}'",
            'reward' => 0.05,
            'lifetime_in_seconds' => 24 * 60 * 60,
            'questions' =>
              [
                {
                  'type' => "selection",
                  'key' => "sentiment",
                  'name' => "Sentiment",
                  'required' => "true",
                  'question' => "Please select the best sentiment value:",
                  'selections' =>
                    [
                      { 'key' => "happy", 'text' => "Happy" },
                      { 'key' => "sad", 'text' => "Sad" },
                      { 'key' => "neutral", 'text' => "Neutral" }
                    ]
                },
                {
                  'type' => "free_text",
                  'key' => "feedback",
                  'name' => "Have any feedback for us?",
                  'required' => "false",
                  'question' => "Feedback",
                  'default' => "Type here...",
                  'min_length' => "2",
                  'max_length' => "2000"
                }
              ]
          }
      }
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def check
      review_hits

      if interpolated['trigger_on'] == "schedule" && (memory['last_schedule'] || 0) <= Time.now.to_i - interpolated['submission_period'].to_i * 60 * 60
        memory['last_schedule'] = Time.now.to_i
        create_basic_hit
      end
    end

    def receive(incoming_events)
      if interpolated['trigger_on'] == "event"
        incoming_events.each do |event|
          create_basic_hit event
        end
      end
    end

    protected

    if defined?(RTurk)

      def take_majority?
        interpolated['combination_mode'] == "take_majority" || interpolated['take_majority'] == "true"
      end

      def create_poll?
        interpolated['combination_mode'] == "poll"
      end

      def event_for_hit(hit_id)
        if memory['hits'][hit_id].is_a?(Hash)
          Event.find_by_id(memory['hits'][hit_id]['event_id'])
        else
          nil
        end
      end

      def hit_type(hit_id)
        if memory['hits'][hit_id].is_a?(Hash) && memory['hits'][hit_id]['type']
          memory['hits'][hit_id]['type']
        else
          'user'
        end
      end

      def review_hits
        reviewable_hit_ids = RTurk::GetReviewableHITs.create.hit_ids
        my_reviewed_hit_ids = reviewable_hit_ids & (memory['hits'] || {}).keys
        if reviewable_hit_ids.length > 0
          log "MTurk reports #{reviewable_hit_ids.length} HITs, of which I own [#{my_reviewed_hit_ids.to_sentence}]"
        end

        my_reviewed_hit_ids.each do |hit_id|
          hit = RTurk::Hit.new(hit_id)
          assignments = hit.assignments

          log "Looking at HIT #{hit_id}.  I found #{assignments.length} assignments#{" with the statuses: #{assignments.map(&:status).to_sentence}" if assignments.length > 0}"
          if assignments.length == hit.max_assignments && assignments.all? { |assignment| assignment.status == "Submitted" }
            inbound_event = event_for_hit(hit_id)

            if hit_type(hit_id) == 'poll'
              # handle completed polls

              log "Handling a poll: #{hit_id}"

              scores = {}
              assignments.each do |assignment|
                assignment.answers.each do |index, rating|
                  scores[index] ||= 0
                  scores[index] += rating.to_i
                end
              end

              top_answer = scores.to_a.sort {|b, a| a.last <=> b.last }.first.first

              payload = {
                'answers' => memory['hits'][hit_id]['answers'],
                'poll' => assignments.map(&:answers),
                'best_answer' => memory['hits'][hit_id]['answers'][top_answer.to_i - 1]
              }

              event = create_event :payload => payload
              log "Event emitted with answer(s) for poll", :outbound_event => event, :inbound_event => inbound_event
            else
              # handle normal completed HITs
              payload = { 'answers' => assignments.map(&:answers) }

              if take_majority?
                counts = {}
                options['hit']['questions'].each do |question|
                  question_counts = question['selections'].inject({}) { |memo, selection| memo[selection['key']] = 0; memo }
                  assignments.each do |assignment|
                    answers = ActiveSupport::HashWithIndifferentAccess.new(assignment.answers)
                    answer = answers[question['key']]
                    question_counts[answer] += 1
                  end
                  counts[question['key']] = question_counts
                end
                payload['counts'] = counts

                majority_answer = counts.inject({}) do |memo, (key, question_counts)|
                  memo[key] = question_counts.to_a.sort {|a, b| a.last <=> b.last }.last.first
                  memo
                end
                payload['majority_answer'] = majority_answer

                if all_questions_are_numeric?
                  average_answer = counts.inject({}) do |memo, (key, question_counts)|
                    sum = divisor = 0
                    question_counts.to_a.each do |num, count|
                      sum += num.to_s.to_f * count
                      divisor += count
                    end
                    memo[key] = sum / divisor.to_f
                    memo
                  end
                  payload['average_answer'] = average_answer
                end
              end

              if create_poll?
                questions = []
                selections = 5.times.map { |i| { 'key' => i+1, 'text' => i+1 } }.reverse
                assignments.length.times do |index|
                  questions << {
                    'type' => "selection",
                    'name' => "Item #{index + 1}",
                    'key' => index,
                    'required' => "true",
                    'question' => interpolate_string(options['poll_options']['row_template'], assignments[index].answers),
                    'selections' => selections
                  }
                end

                poll_hit = create_hit 'title' => options['poll_options']['title'],
                                      'description' => options['poll_options']['instructions'],
                                      'questions' => questions,
                                      'assignments' => options['poll_options']['assignments'],
                                      'lifetime_in_seconds' => options['poll_options']['lifetime_in_seconds'],
                                      'reward' => options['poll_options']['reward'],
                                      'payload' => inbound_event && inbound_event.payload,
                                      'metadata' => { 'type' => 'poll',
                                                      'original_hit' => hit_id,
                                                      'answers' => assignments.map(&:answers),
                                                      'event_id' => inbound_event && inbound_event.id }

                log "Poll HIT created with ID #{poll_hit.id} and URL #{poll_hit.url}.  Original HIT: #{hit_id}", :inbound_event => inbound_event
              else
                if options[:separate_answers]
                  payload['answers'].each.with_index do |answer, index|
                    sub_payload = payload.dup
                    sub_payload.delete('answers')
                    sub_payload['answer'] = answer
                    event = create_event :payload => sub_payload
                    log "Event emitted with answer ##{index}", :outbound_event => event, :inbound_event => inbound_event
                  end
                else
                  event = create_event :payload => payload
                  log "Event emitted with answer(s)", :outbound_event => event, :inbound_event => inbound_event
                end
              end
            end

            assignments.each(&:approve!)
            hit.dispose!

            memory['hits'].delete(hit_id)
          end
        end
      end

      def all_questions_are_numeric?
        interpolated['hit']['questions'].all? do |question|
          question['selections'].all? do |selection|
            selection['key'] == selection['key'].to_f.to_s || selection['key'] == selection['key'].to_i.to_s
          end
        end
      end

      def create_basic_hit(event = nil)
        hit = create_hit 'title' => options['hit']['title'],
                         'description' => options['hit']['description'],
                         'questions' => options['hit']['questions'],
                         'assignments' => options['hit']['assignments'],
                         'lifetime_in_seconds' => options['hit']['lifetime_in_seconds'],
                         'reward' => options['hit']['reward'],
                         'payload' => event && event.payload,
                         'metadata' => { 'event_id' => event && event.id }

        log "HIT created with ID #{hit.id} and URL #{hit.url}", :inbound_event => event
      end

      def create_hit(opts = {})
        payload = opts['payload'] || {}
        title = interpolate_string(opts['title'], payload).strip
        description = interpolate_string(opts['description'], payload).strip
        questions = interpolate_options(opts['questions'], payload)
        hit = RTurk::Hit.create(:title => title) do |hit|
          hit.max_assignments = (opts['assignments'] || 1).to_i
          hit.description = description
          hit.lifetime = (opts['lifetime_in_seconds'] || 24 * 60 * 60).to_i
          hit.question_form AgentQuestionForm.new(:title => title, :description => description, :questions => questions)
          hit.reward = (opts['reward'] || 0.05).to_f
          #hit.qualifications.add :approval_rate, { :gt => 80 }
        end
        memory['hits'] ||= {}
        memory['hits'][hit.id] = opts['metadata'] || {}
        hit
      end

      # RTurk Question Form

      class AgentQuestionForm < RTurk::QuestionForm
        needs :title, :description, :questions

        def question_form_content
          Overview do
            Title do
              text @title
            end
            Text do
              text @description
            end
          end

          @questions.each.with_index do |question, index|
            Question do
              QuestionIdentifier do
                text question['key'] || "question_#{index}"
              end
              DisplayName do
                text question['name'] || "Question ##{index}"
              end
              IsRequired do
                text question['required'] || 'true'
              end
              QuestionContent do
                Text do
                  text question['question']
                end
              end
              AnswerSpecification do
                if question['type'] == "selection"

                  SelectionAnswer do
                    StyleSuggestion do
                      text 'radiobutton'
                    end
                    Selections do
                      question['selections'].each do |selection|
                        Selection do
                          SelectionIdentifier do
                            text selection['key']
                          end
                          Text do
                            text selection['text']
                          end
                        end
                      end
                    end
                  end

                else

                  FreeTextAnswer do
                    if question['min_length'].present? || question['max_length'].present?
                      Constraints do
                        lengths = {}
                        lengths['minLength'] = question['min_length'].to_s if question['min_length'].present?
                        lengths['maxLength'] = question['max_length'].to_s if question['max_length'].present?
                        Length lengths
                      end
                    end

                    if question['default'].present?
                      DefaultText do
                        text question['default']
                      end
                    end
                  end

                end
              end
            end
          end
        end
      end
    end
  end
end
