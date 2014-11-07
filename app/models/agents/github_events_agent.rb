require 'github_api'

module Agents
  class GithubEventsAgent < Agent
    cannot_receive_events!
    default_schedule "every_1h"
    gem_dependency_check { defined?(Github) }

    description <<-MD
      #{'## Include `github_api` in your Gemfile to use this Agent!' if dependencies_missing?}
      The GithubEventsAgent follows the events of a Github user or organization.

      Provide a Github `user` or `org` to monitor.

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    event_description <<-MD
      Events are the raw JSON provided by the Github API. Should look something like:

          {"id"=>"2390633886",
           "type"=>"PullRequestReviewCommentEvent",
           "actor"=>
            {"id"=>66577,
             "login"=>"JakeWharton",
             ...
           "repo"=>
            {"id"=>7764585,
             "name"=>"square/spoon",
             "url"=>"https://api.github.com/repos/square/spoon"},
           "payload"=>
            {"action"=>"created",
             ...
           "public"=>true,
           "created_at"=>"2014-11-06T22:47:57Z",
           "org"=>
            {"id"=>82592,
             "login"=>"square",
             "url"=>"https://api.github.com/orgs/square",
             "avatar_url"=>"https://avatars.githubusercontent.com/u/82592?"
             ...
          }
    MD

    def validate_options
      errors.add(:base, "expected_update_period_in_days option required") unless options[:expected_update_period_in_days].present?
      unless options[:org].present? || options[:user].present?
        errors.add(:base, "The 'user' or 'org' option is required")
      end
    end

    def working?
      event_created_within?(options[:expected_update_period_in_days]) && !recent_error_logs?
    end

    def default_options
      {
        :user => "cantino",
        :expected_update_period_in_days => "2"
      }
    end

    def mode
      if options['user'].present?
        "user-#{options[:user]}"
      elsif options['org'].present?
        "org-#{options[:org]}"
      end
    end

    def github_events
      if options['user'].present?
        Github.activity.events.public(options[:user])
      elsif options['org'].present?
        Github.activity.events.org(options[:org])
      else
        raise "Must provide org or user"
      end
    end

    def check
      events = github_events

      if memory[:mode] == mode
        only_newer_than = memory[:max_event_id]
      else
        only_newer_than = 0
      end

      events.each do |event|
        if event.id > only_newer_than
          create_event :payload => event.as_json
        end
      end

      memory[:max_event_id] = events.map(&:id).max
      memory[:mode] = mode
    end
  end
end

