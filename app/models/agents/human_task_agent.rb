require 'rturk'

module Agents
  class HumanTaskAgent < Agent
    default_schedule "every_10m"

    description <<-MD
      You can use a HumanTaskAgent to create Human Intelligence Tasks (HITs) on Mechanical Turk.

      HITs can be created in response to events, or on a schedule.  Set `trigger_on` to either `schedule` or `event`.

      The schedule of this Agent is how often it should check for completed HITs, __NOT__ how often to submit one.  To configure how often a new HIT
      should be submitted when in `schedule` mode, set `submission_period` to a number of hours.

      If created with an event, all HIT fields can contain interpolated values via [JSONPaths](http://goessner.net/articles/JsonPath/) placed between < and > characters.
      For example, if the incoming event was a Twitter event, you could make a HITT to rate its sentiment like this:

          {
            "expected_receive_period_in_days": 2,
            "trigger_on": "event",
            "hit": {
              "assignments": 1,
              "title": "Sentiment evaluation",
              "description": "Please rate the sentiment of this message: '<$.message>'",
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

      If all of the `questions` are of `type` _selection_, you can set `take_majority` to _true_ at the top level to
      automatically select the majority vote for each question across all `assignments`.  If all selections are numeric, an `average_answer` will also be generated.

      `lifetime_in_seconds` is the number of seconds a HIT is left on Amazon before it's automatically closed.  The default is 1 day.

      As with most Agents, `expected_receive_period_in_days` is required if `trigger_on` is set to `event`.
    MD

    event_description <<-MD
      Events look like:

          {
          }
    MD

    def validate_options
      options[:hit] ||= {}
      options[:hit][:questions] ||= []

      errors.add(:base, "'trigger_on' must be one of 'schedule' or 'event'") unless %w[schedule event].include?(options[:trigger_on])
      errors.add(:base, "'hit.assignments' should specify the number of HIT assignments to create") unless options[:hit][:assignments].present? && options[:hit][:assignments].to_i > 0
      errors.add(:base, "'hit.title' must be provided") unless options[:hit][:title].present?
      errors.add(:base, "'hit.description' must be provided") unless options[:hit][:description].present?
      errors.add(:base, "'hit.questions' must be provided") unless options[:hit][:questions].present? && options[:hit][:questions].length > 0

      if options[:trigger_on] == "event"
        errors.add(:base, "'expected_receive_period_in_days' is required when 'trigger_on' is set to 'event'") unless options[:expected_receive_period_in_days].present?
      elsif options[:trigger_on] == "schedule"
        errors.add(:base, "'submission_period' must be set to a positive number of hours when 'trigger_on' is set to 'schedule'") unless options[:submission_period].present? && options[:submission_period].to_i > 0
      end

      if options[:hit][:questions].any? { |question| [:key, :name, :required, :type, :question].any? {|k| !question[k].present? } }
        errors.add(:base, "all questions must set 'key', 'name', 'required', 'type', and 'question'")
      end

      if options[:hit][:questions].any? { |question| question[:type] == "selection" && (!question[:selections].present? || question[:selections].length == 0 || !question[:selections].all? {|s| s[:key].present? } || !question[:selections].all? { |s| s[:text].present? })}
        errors.add(:base, "all questions of type 'selection' must have a selections array with selections that set 'key' and 'name'")
      end

      if options[:take_majority] == "true" && options[:hit][:questions].any? { |question| question[:type] != "selection" }
        errors.add(:base, "all questions must be of type 'selection' to use the 'take_majority' option")
      end
    end

    def default_options
      {
        :expected_receive_period_in_days => 2,
        :trigger_on => "event",
        :hit =>
          {
            :assignments => 1,
            :title => "Sentiment evaluation",
            :description => "Please rate the sentiment of this message: '<$.message>'",
            :reward => 0.05,
            :lifetime_in_seconds => 24 * 60 * 60,
            :questions =>
              [
                {
                  :type => "selection",
                  :key => "sentiment",
                  :name => "Sentiment",
                  :required => "true",
                  :question => "Please select the best sentiment value:",
                  :selections =>
                    [
                      { :key => "happy", :text => "Happy" },
                      { :key => "sad", :text => "Sad" },
                      { :key => "neutral", :text => "Neutral" }
                    ]
                },
                {
                  :type => "free_text",
                  :key => "feedback",
                  :name => "Have any feedback for us?",
                  :required => "false",
                  :question => "Feedback",
                  :default => "Type here...",
                  :min_length => "2",
                  :max_length => "2000"
                }
              ]
          }
      }
    end

    def working?
      last_receive_at && last_receive_at > options[:expected_receive_period_in_days].to_i.days.ago && !recent_error_logs?
    end

    def check
      review_hits

      if options[:trigger_on] == "schedule" && (memory[:last_schedule] || 0) <= Time.now.to_i - options[:submission_period].to_i * 60 * 60
        memory[:last_schedule] = Time.now.to_i
        create_hit
      end
    end

    def receive(incoming_events)
      if options[:trigger_on] == "event"
        incoming_events.each do |event|
          create_hit event
        end
      end
    end

    protected

    def review_hits
      reviewable_hit_ids = RTurk::GetReviewableHITs.create.hit_ids
      my_reviewed_hit_ids = reviewable_hit_ids & (memory[:hits] || {}).keys.map(&:to_s)
      log "MTurk reports the following HITs [#{reviewable_hit_ids.to_sentence}], of which I own [#{my_reviewed_hit_ids.to_sentence}]"
      my_reviewed_hit_ids.each do |hit_id|
        hit = RTurk::Hit.new(hit_id)
        assignments = hit.assignments

        log "Looking at HIT #{hit_id}.  I found #{assignments.length} assignments#{" with the statuses: #{assignments.map(&:status).to_sentence}" if assignments.length > 0}"
        if assignments.length == hit.max_assignments && assignments.all? { |assignment| assignment.status == "Submitted" }
          payload = { :answers => assignments.map(&:answers) }

          if options[:take_majority] == "true"
            counts = {}
            options[:hit][:questions].each do |question|
              question_counts = question[:selections].inject({}) { |memo, selection| memo[selection[:key]] = 0; memo }
              assignments.each do |assignment|
                answers = ActiveSupport::HashWithIndifferentAccess.new(assignment.answers)
                answer = answers[question[:key]]
                question_counts[answer] += 1
              end
              counts[question[:key]] = question_counts
            end
            payload[:counts] = counts

            majority_answer = counts.inject({}) do |memo, (key, question_counts)|
              memo[key] = question_counts.to_a.sort {|a, b| a.last <=> b.last }.last.first
              memo
            end
            payload[:majority_answer] = majority_answer

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
              payload[:average_answer] = average_answer
            end
          end

          event = create_event :payload => payload
          log "Event emitted with answer(s)", :outbound_event => event, :inbound_event => Event.find_by_id(memory[:hits][hit_id.to_sym])

          assignments.each(&:approve!)

          memory[:hits].delete(hit_id.to_sym)
        end
      end
    end

    def all_questions_are_numeric?
      options[:hit][:questions].all? do |question|
        question[:selections].all? do |selection|
          selection[:key] == selection[:key].to_f.to_s || selection[:key] == selection[:key].to_i.to_s
        end
      end
    end

    def create_hit(event = nil)
      payload = event ? event.payload : {}
      title = Utils.interpolate_jsonpaths(options[:hit][:title], payload).strip
      description = Utils.interpolate_jsonpaths(options[:hit][:description], payload).strip
      questions = Utils.recursively_interpolate_jsonpaths(options[:hit][:questions], payload)
      hit = RTurk::Hit.create(:title => title) do |hit|
        hit.max_assignments = (options[:hit][:assignments] || 1).to_i
        hit.description = description
        hit.lifetime = (options[:hit][:lifetime_in_seconds] || 24 * 60 * 60).to_i
        hit.question_form AgentQuestionForm.new(:title => title, :description => description, :questions => questions)
        hit.reward = (options[:hit][:reward] || 0.05).to_f
        #hit.qualifications.add :approval_rate, { :gt => 80 }
      end
      memory[:hits] ||= {}
      memory[:hits][hit.id] = event && event.id
      log "HIT created with ID #{hit.id} and URL #{hit.url}", :inbound_event => event
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
              text question[:key] || "question_#{index}"
            end
            DisplayName do
              text question[:name] || "Question ##{index}"
            end
            IsRequired do
              text question[:required] || 'true'
            end
            QuestionContent do
              Text do
                text question[:question]
              end
            end
            AnswerSpecification do
              if question[:type] == "selection"

                SelectionAnswer do
                  StyleSuggestion do
                    text 'radiobutton'
                  end
                  Selections do
                    question[:selections].each do |selection|
                      Selection do
                        SelectionIdentifier do
                          text selection[:key]
                        end
                        Text do
                          text selection[:text]
                        end
                      end
                    end
                  end
                end

              else

                FreeTextAnswer do
                  if question[:min_length].present? || question[:max_length].present?
                    Constraints do
                      lengths = {}
                      lengths[:minLength] = question[:min_length].to_s if question[:min_length].present?
                      lengths[:maxLength] = question[:max_length].to_s if question[:max_length].present?
                      Length lengths
                    end
                  end

                  if question[:default].present?
                    DefaultText do
                      text question[:default]
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