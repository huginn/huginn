require 'csv'

module Agents
  class SentimentAgent < Agent
    class_attribute :anew

    cannot_be_scheduled!

    description <<-MD
      The Sentiment Agent generates `good-bad` (psychological valence or happiness index), `active-passive` (arousal), and  `strong-weak` (dominance) score. It will output a value between 1 and 9. It will only work on English content.

      Make sure the content this agent is analyzing is of sufficient length to get respectable results.

      Provide a JSONPath in `content` field where content is residing and set `expected_receive_period_in_days` to the maximum number of days you would allow to be passed between events being received by this agent.
    MD

    event_description <<-MD
      Events look like:

          {
            "content": "The quick brown fox jumps over the lazy dog.",
            "valence": 6.196666666666666,
            "arousal": 4.993333333333333,
            "dominance": 5.63
          }
    MD

    def default_options
      {
        'content' => "$.message.text[*]",
        'expected_receive_period_in_days' => 1
      }
    end

    def working?
      last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago && !recent_error_logs?
    end

    def receive(incoming_events)
      anew = self.class.sentiment_hash
      incoming_events.each do |event|
        Utils.values_at(event.payload, interpolated['content']).each do |content|
          sent_values = sentiment_values anew, content
          create_event :payload => { 'content' => content,
                                     'valence' => sent_values[0],
                                     'arousal' => sent_values[1],
                                     'dominance' => sent_values[2],
                                     'original_event' => event.payload }
        end
      end
    end

    def validate_options
      errors.add(:base, "content and expected_receive_period_in_days must be present") unless options['content'].present? && options['expected_receive_period_in_days'].present?
    end

    def self.sentiment_hash
      unless self.anew
        self.anew = {}
        CSV.foreach Rails.root.join('data/anew.csv') do |row|
          self.anew[row[0]] = row.values_at(2, 4, 6).map { |val| val.to_f }
        end
      end
      self.anew
    end

    def sentiment_values(anew, text)
      valence, arousal, dominance, freq = [0] * 4
      text.downcase.strip.gsub(/[^a-z ]/, "").split.each do |word|
        if anew.has_key? word
          valence += anew[word][0]
          arousal += anew[word][1]
          dominance += anew[word][2]
          freq += 1
        end
      end
      if valence != 0
        [valence/freq, arousal/freq, dominance/freq]
      else
        ["Insufficient data for meaningful answer"] * 3
      end
    end
  end
end