require 'github_api'

module Agents
  class GithubEventsAgent < Agent
    cannot_receive_events!
    
    gem_dependency_check { defined?(Github) }
    
    description <<-MD
      #{'## Include `github_api` in your Gemfile to use this Agent!' if dependencies_missing?}
      The GithubEventsAgent follows the events of the Github user or org events.

      You have to set the `user` or `org` of the Github user to monitor.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    event_description <<-MD
      Events are the raw JSON provided by the Github API. Should look something like:


    MD




    default_schedule "every_1h"

    def validate_options
      unless options[:org].present? || options[:user].present? && options[:expected_update_period_in_days].present? 
        errors.add(:base, "expected_update_period_in_days, org are required")
      end
    end

    def working?
      event_created_within?(options[:expected_update_period_in_days]) && !recent_error_logs?
    end

    def default_options
      {
          :org => "open3dengineering",
          :user => "cantino",
          :expected_update_period_in_days => "2"
      }
    end

    def check


  
#      since_id = memory[:since_id] || nil
#      opts = {:count => 200, :include_rts => true, :exclude_replies => false, :include_entities => true, :contributor_details => true}
#      opts.merge! :since_id => since_id unless since_id.nil?

      if !options[:org]
        events = Github.activity.events.public(options[:user])
      else
        events = Github.activity.events.org(options[:org])
      end

      self.memory[:ids] ||= []

      events.each do |event|

        if !memory[:ids] || (!memory[:ids].include?(event.id))        

          memory[:ids].push(event.id)

          create_event :payload => event  
        end
      end

      save!
    end
  end
end


