module Agents
  class AppfiguresReviewsAgent < WebsiteAgent
    include FormConfigurable

    description <<-MD
      The AppFigures Agent pulls reviews via [AppFigures API](http://docs.appfigures.com/api/reference/v2/reviews) either for all apps on a given account or
      a reviews for predefined products using AppFigures Public Data API if `products` attribute is defined.

      THe Public Data API uses paid credits and should thus only be used when other options are not available. To get the product ids you need to run the following query: `api.appfigures.com/v2/products/search/@name=app_name`.
      Then list products in the `products` option with a comma.

      The `filters` option is set up to fetch 500 reviews by default and convert them to English automatically. You can find the full list of available params [here](http://docs.appfigures.com/api/reference/v2/reviews).

      `basic_auth` option is supposed to have your AppFigures Login and Password with a colon in between: `login:password`. You should not have actual credentials here, instead save on the Credentials tab as explained [here]()

      `client_key` option has your AppFigures API Client Key, get one [here](https://appfigures.com/developers/keys)
    MD

    EXTRACT = {
      'title' => {
        'path' => 'reviews[*].title'
      },
      'comment' => {
        'path' => 'reviews[*].review'
      },
      'appfigures_id' => {
        'path' => 'reviews[*].id'
      },
      'score' => {
        'path' => 'reviews[*].stars'
      },
      'stream' => {
        'path' => 'reviews[*].store'
      },
      'created_at' => {
        'path' => 'reviews[*].date'
      },
      'iso' => {
        'path' => 'reviews[*].iso'
      },
      'author' => {
        'path' => 'reviews[*].author'
      },
      'version' => {
        'path' => 'reviews[*].version'
      },
      'app' => {
        'path' => 'reviews[*].product_name'
      }
    }.freeze

    can_dry_run!
    can_order_created_events!
    no_bulk_receive!

    default_schedule "every_5h"

    before_validation :build_default_options

    form_configurable :filter
    form_configurable :client_key
    form_configurable :basic_auth
    form_configurable :products
    form_configurable :mode, type: :array, values: %w(all on_change merge)
    form_configurable :expected_update_period_in_days

    def default_options
      {
        'filter' => 'lang=en&count=5',
        'client_key' => '{% credential AppFiguresClientKey %}',
        'basic_auth' => '{% credential AppFiguresUsername %}:{% credential AppFiguresPassword %}',
        'expected_update_period_in_days' => '1',
        'mode' => 'on_change'
      }
    end

    private

    def build_default_options
      options['filter'] << "&#{options['products']}" if options['products'].present?
      options['url'] = "https://api.appfigures.com/v2/reviews"
      options['url'] << "#{options['filter']}" if options['filter'].present?
      options['headers'] = auth_header(
        options['client_key']
      )
      options['type'] = 'json'
      options['extract'] = EXTRACT
    end

    def auth_header(client_key)
      {
        'X-Client-Key' => client_key
      }
    end
  end
end
