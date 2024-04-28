# If you use gems that require environment variables to be set before they are
# loaded, then list `dotenv` in the `Gemfile` before those other gems and
# require `dotenv/load`.
#
#     gem "dotenv", require: "dotenv/load"
#     gem "gem-that-requires-env-variables"
#

require "dotenv/load"
warn '[DEPRECATION] `require "dotenv/rails-now"` is deprecated. Use `require "dotenv/load"` instead.', caller(1..1).first
