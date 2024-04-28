require "dotenv/parser"
require "dotenv/environment"
require "dotenv/missing_keys"
require "dotenv/diff"

# Shim to load environment variables from `.env files into `ENV`.
module Dotenv
  extend self

  # An internal monitor to synchronize access to ENV in multi-threaded environments.
  SEMAPHORE = Monitor.new
  private_constant :SEMAPHORE

  attr_accessor :instrumenter

  # Loads environment variables from one or more `.env` files. See `#parse` for more details.
  def load(*filenames, overwrite: false, ignore: true)
    parse(*filenames, overwrite: overwrite, ignore: ignore) do |env|
      instrument(:load, env: env) do |payload|
        update(env, overwrite: overwrite)
      end
    end
  end

  # Same as `#load`, but raises Errno::ENOENT if any files don't exist
  def load!(*filenames)
    load(*filenames, ignore: false)
  end

  # same as `#load`, but will overwrite existing values in `ENV`
  def overwrite(*filenames)
    load(*filenames, overwrite: true)
  end
  alias_method :overload, :overwrite

  # same as `#overwrite`, but raises Errno::ENOENT if any files don't exist
  def overwrite!(*filenames)
    load(*filenames, overwrite: true, ignore: false)
  end
  alias_method :overload!, :overwrite!

  # Parses the given files, yielding for each file if a block is given.
  #
  # @param filenames [String, Array<String>] Files to parse
  # @param overwrite [Boolean] Overwrite existing `ENV` values
  # @param ignore [Boolean] Ignore non-existent files
  # @param block [Proc] Block to yield for each parsed `Dotenv::Environment`
  # @return [Hash] parsed key/value pairs
  def parse(*filenames, overwrite: false, ignore: true, &block)
    filenames << ".env" if filenames.empty?
    filenames = filenames.reverse if overwrite

    filenames.reduce({}) do |hash, filename|
      begin
        env = Environment.new(File.expand_path(filename), overwrite: overwrite)
        env = block.call(env) if block
      rescue Errno::ENOENT
        raise unless ignore
      end

      hash.merge! env || {}
    end
  end

  # Save the current `ENV` to be restored later
  def save
    instrument(:save) do |payload|
      @diff = payload[:diff] = Dotenv::Diff.new
    end
  end

  # Restore `ENV` to a given state
  #
  # @param env [Hash] Hash of keys and values to restore, defaults to the last saved state
  # @param safe [Boolean] Is it safe to modify `ENV`? Defaults to `true` in the main thread, otherwise raises an error.
  def restore(env = @diff&.a, safe: Thread.current == Thread.main)
    diff = Dotenv::Diff.new(b: env)
    return unless diff.any?

    unless safe
      raise ThreadError, <<~EOE.tr("\n", " ")
        Dotenv.restore is not thread safe. Use `Dotenv.modify { }` to update ENV for the duration
        of the block in a thread safe manner, or call `Dotenv.restore(safe: true)` to ignore
        this error.
      EOE
    end
    instrument(:restore, diff: diff) { ENV.replace(env) }
  end

  # Update `ENV` with the given hash of keys and values
  #
  # @param env [Hash] Hash of keys and values to set in `ENV`
  # @param overwrite [Boolean] Overwrite existing `ENV` values
  def update(env = {}, overwrite: false)
    instrument(:update) do |payload|
      diff = payload[:diff] = Dotenv::Diff.new do
        ENV.update(env.transform_keys(&:to_s)) do |key, old_value, new_value|
          # This block is called when a key exists. Return the new value if overwrite is true.
          overwrite ? new_value : old_value
        end
      end
      diff.env
    end
  end

  # Modify `ENV` for the block and restore it to its previous state afterwards.
  #
  # Note that the block is synchronized to prevent concurrent modifications to `ENV`,
  # so multiple threads will be executed serially.
  #
  # @param env [Hash] Hash of keys and values to set in `ENV`
  def modify(env = {}, &block)
    SEMAPHORE.synchronize do
      diff = Dotenv::Diff.new
      update(env, overwrite: true)
      block.call
    ensure
      restore(diff.a, safe: true)
    end
  end

  def require_keys(*keys)
    missing_keys = keys.flatten - ::ENV.keys
    return if missing_keys.empty?
    raise MissingKeys, missing_keys
  end

  private

  def instrument(name, payload = {}, &block)
    if instrumenter
      instrumenter.instrument("#{name}.dotenv", payload, &block)
    else
      block&.call payload
    end
  end
end

require "dotenv/rails" if defined?(Rails::Railtie)
