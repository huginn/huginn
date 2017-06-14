# Set the timezone for the JavascriptAgent (libv8 only relies on the TZ variable)
ENV['TZ'] = Time.zone.tzinfo.canonical_identifier
