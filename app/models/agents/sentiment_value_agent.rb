require 'csv'

module Agents
	class SentimentValueAgent < Agent
		description <<-MD
			The SentimentValueAgent generates `good-bad` (psychological valence or happiness index),`active-passive` (arousal), and `strong-weak` (dominance) score. It will output a value between 1 and 9. Make sure the content this agent is running on have sufficient length.
			Add more stuff
		MD

		event_description <<-MD
			Events look like:
			{
				:valence   => 4.5
				:arousal   => 4.5
				:dominance => 4.5
			}
		MD

		default_schedule "every_1h"

		def default_options
			{

			}
		end

		def working?
			true
		end

		def receive(incoming_events)
            incoming_events.each do |event|
                self.memory[:queue] ||= []
                self.memory[:queue] << event.payload
            end
        end

        def validate_options
        end

        def sentiment_hash
        	anew = {}
        	CSV.foreach Rails.root.join('app/assets/anew.csv') do |row|
        		anew[row[0]] = [row[2],row[4],row[6]].map {|val| val.to_f}
        	end
        	anew
        end

        def sentiment_values(anew,text)
        	valence, arousal, dominance, freq = [0] * 4
        	text.downcase.strip.gsub(/[^a-z ]/,"").split.each do |word|
        		if anew.has_key?(word)
        			valence   += anew[word][0]
        			arousal   += anew[word][1]
        			dominance += anew[word][2]
        			freq      += 1
        		end
        	end
        	if valence != 0
        		[valence/freq, arousal/freq, dominance/freq]
        	else
        		["Insufficient data for meaningful answer"] * 3
        	end


        end

        def check
        	if self.memory[:queue] && self.memory[:queue].length > 0
        		anew = sentiment_hash
        		self.memory[:queue].each do |text|
        			if text[:message]
        				sent_values = sentiment_values anew, text[:message]
        				create_event :payload => {:content => text[:message], :valence => sent_values[0], :arousal => sent_values[1], :dominance => sent_values[2]}
        			end
        		end
        		self.memory[:queue] = []
        	end
        end


	end
end