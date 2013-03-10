require 'nokogiri'
require 'typhoeus'
require 'date'

module Agents
  class WebsiteAgent < Agent
    cannot_receive_events!

    description <<-MD
      The WebsiteAgent scrapes a website and creates Events based on any changes in the results.

      Specify the website's `url` and select a `mode` for when to create Events based on the scraped data, either `all` or `on_change`.

      To tell the Agent how to scrape the site, specify `extract` as a hash with keys naming the extractions and values of hashes.
      These subhashes specify how to extract with a `:css` CSS selector and either `:text => true` or `attr` pointing to an attribute name to grab.  An example:

          :extract => {
            :url => { :css => "#comic img", :attr => "src" },
            :title => { :css => "#comic img", :attr => "title" },
            :body_text => { :css => "div.main", :text => true }
          }

      Note that whatever you extract MUST have the same number of matches for each extractor.  E.g., if you're extracting rows, all extractors must match all rows.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    event_description do <<-MD
      Events will have the fields you specified.  Your options look like:

          #{PP.pp(options[:extract], "")}
      MD
    end

    default_schedule "every_12h"

    UNIQUENESS_LOOK_BACK = 30

    def working?
      (event = event_created_within(options[:expected_update_period_in_days].to_i.days)) && event.payload.present?
    end

    def default_options
      {
          :expected_update_period_in_days => "2",
          :url => "http://xkcd.com",
          :mode => :on_change,
          :extract => {
              :url => {:css => "#comic img", :attr => "src"},
              :title => {:css => "#comic img", :attr => "title"}
          }
      }
    end

    def validate_options
      errors.add(:base, "url, expected_update_period_in_days, and extract are required") unless options[:expected_update_period_in_days].present? && options[:url].present? && options[:extract].present?
    end

    def check
      hydra = Typhoeus::Hydra.new
      request = Typhoeus::Request.new(options[:url], :followlocation => true)
      request.on_complete do |response|
        doc = (options[:type].to_s == "xml" || options[:url] =~ /\.(rss|xml)$/i) ? Nokogiri::XML(response.body) : Nokogiri::HTML(response.body)
        output = {}
        options[:extract].each do |name, extraction_details|
          output[name] = doc.css(extraction_details[:css]).map { |node|
            if extraction_details[:attr]
              node.attr(extraction_details[:attr])
            elsif extraction_details[:text]
              node.text()
            else
              raise StandardError, ":attr or :text is required on each of the extraction patterns."
            end
          }
        end

        num_unique_lengths = options[:extract].keys.map { |name| output[name].length }.uniq

        raise StandardError, "Got an uneven number of matches for #{options[:name]}: #{options[:extract].inspect}" unless num_unique_lengths.length == 1

        previous_payloads = events.order("id desc").limit(UNIQUENESS_LOOK_BACK).pluck(:payload) if options[:mode].to_s == "on_change"
        num_unique_lengths.first.times do |index|
          result = {}
          options[:extract].keys.each do |name|
            result[name] = output[name][index]
          end

          if !options[:mode] || options[:mode].to_s == "all" || (options[:mode].to_s == "on_change" && !previous_payloads.include?(result))
            Rails.logger.info "Storing new result for '#{options[:name]}': #{result.inspect}"
            create_event :payload => result
          end
        end
      end
      hydra.queue request
      hydra.run
    end
  end
end