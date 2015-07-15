require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.allow_http_connections_when_no_cassette = false
  c.hook_into :webmock
  c.default_cassette_options = { record: :new_episodes}
  c.configure_rspec_metadata!
end