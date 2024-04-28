module Dotenv
  # A diff between multiple states of ENV.
  class Diff
    # The initial state
    attr_reader :a

    # The final or current state
    attr_reader :b

    # Create a new diff. If given a block, the state of ENV after the block will be preserved as
    # the final state for comparison. Otherwise, the current ENV will be the final state.
    #
    # @param a [Hash] the initial state, defaults to a snapshot of current ENV
    # @param b [Hash] the final state, defaults to the current ENV
    # @yield [diff] a block to execute before recording the final state
    def initialize(a: snapshot, b: ENV, &block)
      @a, @b = a, b
      block&.call self
    ensure
      @b = snapshot if block
    end

    # Return a Hash of keys added with their new values
    def added
      b.slice(*(b.keys - a.keys))
    end

    # Returns a Hash of keys removed with their previous values
    def removed
      a.slice(*(a.keys - b.keys))
    end

    # Returns of Hash of keys changed with an array of their previous and new values
    def changed
      (b.slice(*a.keys).to_a - a.to_a).map do |(k, v)|
        [k, [a[k], v]]
      end.to_h
    end

    # Returns a Hash of all added, changed, and removed keys and their new values
    def env
      b.slice(*(added.keys + changed.keys)).merge(removed.transform_values { |v| nil })
    end

    # Returns true if any keys were added, removed, or changed
    def any?
      [added, removed, changed].any?(&:any?)
    end

    private

    def snapshot
      ENV.to_h.freeze
    end
  end
end
