require 'uri'

module Agents
  class AftershipAgent < Agent

    API_URL = 'https://api.aftership.com/v4'

    description <<-MD
      The Aftership agent allows you to track your shipment from aftership and emit them into events.

      To be able to use the Aftership API, you need to generate an `API Key`. You do need a paying plan to use their tracking feature.

      You need a key value pair to retrieve data. The key are `get_url` and `delete_url`.

      The options are `/trackings/export` to get tracking results for backup purposes, `/trackings/slug/tracking_number` to get tracking 
      for a single tracking number, `/last_checkpoint/:slug/:tracking_number` for last checkpoint of a single tracking and `/trackings` to get all of your trackings. 
      You have two options to get courier information, `/couriers` 
      which returns the couriers that are activiated at your account and the other is `/couriers/all` which returns all couriers.
      `slug` is a unique courier code which you can get from using this agent.

      If specified most url must be properly formatted with a `/` in front.

      The delete option allows you to delete a specific shipment. You must provide `slug` and `tracking number`.

      Required Options:

      * `Content-Type` application/json
      * `api_key` - YOUR_API_KEY.
      * `key value pair request`
    MD

    event_description <<-MD
      It depends what kind of event that you are working on:
      MD

    def default_options
      { 'api_key' => 'YOUR_API_KEY',
        'Content_Type' => 'application/json',
        'delete_url' => '/trackings',
        'slug' => '/usps',
        'tracking_number' => ''
      }
    end

    def uri
      uri = URI.parse API_URL
      if options['get_url']
        uri.query = interpolated['get_url'] if uri.query.nil?
      elsif options['delete_url']
        uri.query = interpolated['delete_url'] + interpolated['slug'] + '/' + interpolated['tracking_number'] if uri.query.nil?
      end
      uri.to_s.gsub('?','') 
    end

    def working?
      (events_count.present? && events_count > 0)
    end

    def validate_options
      errors.add(:base, "You need to specify a api key") unless options['api_key'].present?
      errors.add(:base, "Content-Type must be set to application/json") unless options['Content_Type'].present? && options['Content_Type'] == 'application/json'
      #errors.add(:base, "You need to specify a certain request") unless options['get_url'].present? && options['delete_url'].present?
    end

    def request_options
      {:headers => {"aftership-api-key" => interpolated['api_key'], "Content-Type"=>"application/json"} }
    end

    def check
      response = HTTParty.get(uri, request_options)
      events = JSON.parse response.body
      create_event :payload => events
      if options['delete_url']
        delete = HTTParty.delete(uri, request_options)
        #create_event :payload => delete
      end
    end
  end
end
