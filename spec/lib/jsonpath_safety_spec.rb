require "rails_helper"

describe JsonpathSafety do # rubocop:disable Metrics/BlockLength
  describe "guarded references" do # rubocop:disable Metrics/BlockLength
    around do |example|
      @calls = []
      calls = @calls
      Kernel.module_eval do
        define_method(:jsonpath_private_probe) do
          calls << self
        end
        private :jsonpath_private_probe
        define_method(:jsonpath_public_probe) do
          calls << self
        end
        public :jsonpath_public_probe
      end
      example.run
    ensure
      Kernel.module_eval do
        remove_method :jsonpath_private_probe, :jsonpath_public_probe
      end
    end

    [true, false].each do |allow_send|
      %w[jsonpath_private_probe jsonpath_public_probe].each do |name|
        it "never calls #{name} with allow_send: #{allow_send}" do
          [nil, false, true, 1, 1.5, "text", [], {}].each do |value|
            [
              ["$.a.#{name}", { "a" => value }],
              ["$.a[?(@.#{name})]", { "a" => [value] }],
              ["$.a[?(@['#{name}'])]", { "a" => [value] }],
              ["$.a[?(@.child.#{name})]", { "a" => [{ "child" => value }] }],
              ["$.a[?(@[0].#{name})]", { "a" => [[value]] }],
              ["$.a[(@.#{name})]", { "a" => [value] }],
              ["$.a(#{name})", { "a" => [{ "child" => value }] }],
            ].each do |path, data|
              JsonPath.new(path, allow_send: allow_send).on(data)
            end
          end

          expect(@calls).to be_empty
        end
      end
    end

    it "does not traverse Ruby classes or expose unlisted methods" do
      expect(JsonPath.new("$.a.class.name").on("a" => 1)).to eq([])
      expect(JsonPath.new("$.a[?(@.class.name)]").on("a" => [1])).to eq([])
      expect(JsonPath.new("$.a.inspect").on("a" => "text")).to eq([])
      expect(JsonPath.new("$.a[?(@.reverse)]").on("a" => [[1]])).to eq([])
    end

    it "does not call custom dig methods" do
      node = double("custom node")
      expect(node).not_to receive(:dig)

      expect(JsonPath.new("$.a.value").on("a" => node)).to eq([])
      expect(JsonPath.new("$.a[?(@.child.value)]").on("a" => [{ "child" => node }])).to eq([])
    end

    it "still reads keys whose names coincide with Ruby methods" do
      data = { "a" => [{ "abort" => true, "class" => { "name" => "example" } }] }

      expect(JsonPath.new("$.a[?(@.abort)].class.name").on(data)).to eq(["example"])
      expect(JsonPath.new("$.a[0].abort").first(data)).to eq(true)
    end
  end

  describe "legacy compatibility" do # rubocop:disable Metrics/BlockLength
    [true, false].each do |allow_send|
      it "allows safe operations through every reference path with allow_send: #{allow_send}" do
        data = { "text" => " AbC ", "items" => %w[HELLO other], "empty" => [], "object" => { "a" => 1 } }
        lookup = ->(path) { JsonPath.new(path, allow_send: allow_send).on(data) }
        expect(lookup.call("$.text.strip.downcase")).to eq(["abc"])
        expect(lookup.call("$.text.upcase")).to eq([" ABC "])
        expect(lookup.call("$.text.length")).to eq([5])
        expect(lookup.call("$.items.size")).to eq([2])
        expect(lookup.call("$.empty['empty?']")).to eq([true])
        expect(lookup.call("$.text['present?']")).to eq([true])
        expect(lookup.call("$.empty['blank?']")).to eq([true])
        expect(lookup.call("$.items.first.downcase")).to eq(["hello"])
        expect(lookup.call("$.items.last")).to eq(["other"])
        expect(lookup.call("$.object.size")).to eq([1])
        expect(lookup.call("$.object['present?']")).to eq([true])
        expect(lookup.call('$.items[?(@.downcase == "hello")]')).to eq(["HELLO"])
        expect(lookup.call("$.items[(@.length-1)]")).to eq(["other"])
        expect(lookup.call("$.text.downcase.class.name")).to eq([])
      end
    end

    it "preserves Hash keys and restricts method access to the listed types" do
      expect(JsonPath.new("$.a.length").on("a" => { "length" => "key" })).to eq(["key"])
      expect(JsonPath.new("$.a.length").on("a" => { "length" => nil })).to eq([nil])
      expect(JsonPath.new("$.a['empty?']").on("a" => { "empty?" => false })).to eq([false])
      expect(JsonPath.new("$.a.length").on("a" => {})).to eq([0])
      expect(JsonPath.new("$.a.first").on("a" => { "b" => 1 })).to eq([])
      subclass = Class.new(String).new("HELLO")
      expect(JsonPath.new("$.a.downcase").on("a" => subclass)).to eq([])
    end

    it "supports presence checks and endpoint access inside filters" do
      data = { "words" => ["", " ", "hello"], "lists" => [[], ["hello"]], "objects" => [{}, { "a" => 1 }] }
      expect(JsonPath.new("$.words[?(@.blank?)]").on(data)).to eq(["", " "])
      expect(JsonPath.new("$.lists[?(@.present?)]").on(data)).to eq([["hello"]])
      expect(JsonPath.new('$.lists[?(@.first == "hello")]').on(data)).to eq([["hello"]])
      expect(JsonPath.new("$.objects[?(@.size > 0)]").on(data)).to eq([{ "a" => 1 }])
    end

    it "retains root omission and whole-document aliases for saved settings" do
      data = { "foo" => { "bar" => 2 } }

      expect(JsonPath.new("foo.bar").on(data)).to eq([2])
      ["", ".", "$"].each do |path|
        expect(JsonPath.new(path).on(data)).to eq([data])
      end
    end

    it "retains numeric coercion, regular expressions, and object filters" do
      data = { "tags" => [{ "name" => "0.299" }, { "name" => "0" }, { "name" => "master" }] }

      expect(JsonPath.new("$.tags[?(@.name>0)].name").on(data)).to eq(["0.299"])
      expect(JsonPath.new("$.tags[?(@.name =~ /master/)].name").on(data)).to eq(["master"])
      expect(JsonPath.new("$.foo.bar[?(@.bing == 2)].bing").on("foo" => { "bar" => { "bing" => 2 } })).to eq([2])
    end

    it "retains comparisons on scalar array elements and nested array indexes" do
      expect(JsonPath.new("$.a[?(@ > 1)]").on("a" => [0, 2, 3])).to eq([2, 3])
      expect(JsonPath.new("$.a[?(@[0].n == 2)]").on("a" => [[{ "n" => 2 }]])).to eq([[{ "n" => 2 }]])
    end
  end
end
