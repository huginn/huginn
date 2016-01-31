require 'open-uri'
require 'hypdf'

module Agents
  class PdfInfoAgent < Agent

    gem_dependency_check { defined?(HyPDF) }

    cannot_be_scheduled!
    no_bulk_receive!

    description <<-MD
      The PDF Info Agent returns the metadata contained within a given PDF file, using HyPDF.

      #{'## Include the `hypdf` gem in your `Gemfile` to use PDFInfo Agents.' if dependencies_missing?}

      In order for this agent to work, you need to have [HyPDF](https://devcenter.heroku.com/articles/hypdf) running and configured.

      It works by acting on events that contain a key `url` in their payload, and runs the [pdfinfo](https://devcenter.heroku.com/articles/hypdf#pdfinfo) command on them.
    MD

    event_description <<-MD
    This will change based on the metadata in the pdf.

      { "Title"=>"Everyday Rails Testing with RSpec", 
        "Author"=>"Aaron Sumner",
        "Creator"=>"LaTeX with hyperref package",
        "Producer"=>"xdvipdfmx (0.7.8)",
        "CreationDate"=>"Fri Aug  2 05",
        "32"=>"50 2013",
        "Tagged"=>"no",
        "Pages"=>"150",
        "Encrypted"=>"no",
        "Page size"=>"612 x 792 pts (letter)",
        "Optimized"=>"no",
        "PDF version"=>"1.5",
        "url": "your url"
      }
    MD

    def working?
      !recent_error_logs?
    end

    def default_options
      {}
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          url_to_scrape = event.payload['url']
          check_url(url_to_scrape, event.payload) if url_to_scrape =~ /^https?:\/\//i
        end
      end
    end

    def check_url(in_url, payload)
      return unless in_url.present?
      Array(in_url).each do |url|
        log "Fetching #{url}"
        info = HyPDF.pdfinfo(open(url))
        create_event :payload => info.merge(payload)
      end
    end

  end
end
