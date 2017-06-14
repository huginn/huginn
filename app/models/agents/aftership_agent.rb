require 'uri'

module Agents
  class AftershipAgent < Agent

    cannot_receive_events!

    default_schedule "every_10m"

    description <<-MD
      The Aftership agent allows you to track your shipment from aftership and emit them into events.

      To be able to use the Aftership API, you need to generate an `API Key`. You need a paying plan to use their tracking feature.

      You can use this agent to retrieve tracking data.
 
      Provide the `path` for the API endpoint that you'd like to hit. For example, for all active packages, enter `trackings` 
      (see https://www.aftership.com/docs/api/4/trackings), for a specific package, use `trackings/SLUG/TRACKING_NUMBER` 
      and replace `SLUG` with a courier code and `TRACKING_NUMBER` with the tracking number. You can request last checkpoint of a package 
      by providing `last_checkpoint/SLUG/TRACKING_NUMBER` instead.

      You can get a list of courier information here `https://www.aftership.com/courier`

      Required Options:

      * `api_key` - YOUR_API_KEY.
      * `path request and its full path`
    MD

    event_description <<-MD
      A typical tracking event have 2 important objects (tracking, and checkpoint) and the tracking/checkpoint looks like this.

          "trackings": [
            {
                "id": "53aa7b5c415a670000000021",
                "created_at": "2014-06-25T07:33:48+00:00",
                "updated_at": "2014-06-25T07:33:55+00:00",
                "tracking_number": "123456789",
                "tracking_account_number": null,
                "tracking_postal_code": null,
                "tracking_ship_date": null,
                "slug": "dhl",
                "active": false,
                "custom_fields": {
                    "product_price": "USD19.99",
                    "product_name": "iPhone Case"
                },
                "customer_name": null,
                "destination_country_iso3": null,
                "emails": [
                    "email@yourdomain.com",
                    "another_email@yourdomain.com"
                ],
                "expected_delivery": null,
                "note": null,
                "order_id": "ID 1234",
                "order_id_path": "http://www.aftership.com/order_id=1234",
                "origin_country_iso3": null,
                "shipment_package_count": 0,
                "shipment_type": null,
                "signed_by": "raul",
                "smses": [],
                "source": "api",
                "tag": "Delivered",
                "title": "Title Name",
                "tracked_count": 1,
                "unique_token": "xy_fej9Llg",
                "checkpoints": [
                    {
                        "slug": "dhl",
                        "city": null,
                        "created_at": "2014-06-25T07:33:53+00:00",
                        "country_name": "VALENCIA - SPAIN",
                        "message": "Awaiting collection by recipient as requested",
                        "country_iso3": null,
                        "tag": "InTransit",
                        "checkpoint_time": "2014-05-12T12:02:00",
                        "coordinates": [],
                        "state": null,
                        "zip": null
                    },
                    ...
                ]
            },
            ...
        ]
    MD

    def default_options
      { 'api_key' => 'YOUR_API_KEY',
        'path' => 'trackings'
      }
    end

    def working?
      !recent_error_logs?
    end

    def validate_options
      errors.add(:base, "You need to specify a api key") unless options['api_key'].present?
      errors.add(:base, "You need to specify a path request") unless options['path'].present?
    end

    def check
      response = HTTParty.get(event_url, request_options)
      events = JSON.parse response.body
      create_event :payload => events
    end

  private
    def base_url
      "https://api.aftership.com/v4/"
    end

    def event_url
      base_url + "#{URI.encode(interpolated[:path].to_s)}"
    end

    def request_options
      {:headers => {"aftership-api-key" => interpolated['api_key'], "Content-Type"=>"application/json"} }
    end
  end
end
