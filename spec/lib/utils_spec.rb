require 'rails_helper'

describe Utils do
  describe "#unindent" do
    it "unindents to the level of the greatest consistant indention" do
      expect(Utils.unindent(<<-MD)).to eq("Hello World")
        Hello World
      MD

      expect(Utils.unindent(<<-MD)).to eq("Hello World\nThis is\nnot indented")
        Hello World
        This is
        not indented
      MD

      expect(Utils.unindent(<<-MD)).to eq("Hello World\n  This is\n  indented\nthough")
        Hello World
          This is
          indented
        though
      MD

      expect(Utils.unindent("Hello\n  I am indented")).to eq("Hello\n  I am indented")

      a = "        Events will have the fields you specified.  Your options look like:\n\n            {\n      \"url\": {\n        \"css\": \"#comic img\",\n        \"value\": \"@src\"\n      },\n      \"title\": {\n        \"css\": \"#comic img\",\n        \"value\": \"@title\"\n      }\n    }\"\n"
      expect(Utils.unindent(a)).to eq("Events will have the fields you specified.  Your options look like:\n\n    {\n      \"url\": {\n\"css\": \"#comic img\",\n\"value\": \"@src\"\n      },\n      \"title\": {\n\"css\": \"#comic img\",\n\"value\": \"@title\"\n      }\n    }\"")
    end
  end

  describe "#interpolate_jsonpaths" do
    let(:payload) { { :there => { :world => "WORLD" }, :works => "should work" } }

    it "interpolates jsonpath expressions between matching <>'s" do
      expect(Utils.interpolate_jsonpaths("hello <$.there.world> this <escape works>", payload)).to eq("hello WORLD this should+work")
    end

    it "optionally supports treating values that start with '$' as raw JSONPath" do
      expect(Utils.interpolate_jsonpaths("$.there.world", payload)).to eq("$.there.world")
      expect(Utils.interpolate_jsonpaths("$.there.world", payload, :leading_dollarsign_is_jsonpath => true)).to eq("WORLD")
    end
  end

  describe "#recursively_interpolate_jsonpaths" do
    it "interpolates all string values in a structure" do
      struct = {
        :int => 5,
        :string => "this <escape $.works>",
        :array => ["<works>", "now", "<$.there.world>"],
        :deep => {
          :string => "hello <there.world>",
          :hello => :world
        }
      }
      data = { :there => { :world => "WORLD" }, :works => "should work" }
      expect(Utils.recursively_interpolate_jsonpaths(struct, data)).to eq({
        :int => 5,
        :string => "this should+work",
        :array => ["should work", "now", "WORLD"],
        :deep => {
          :string => "hello WORLD",
          :hello => :world
        }
      })
    end
  end

  describe "#value_at" do
    it "returns the value at a JSON path" do
      expect(Utils.value_at({ :foo => { :bar => :baz }}.to_json, "foo.bar")).to eq("baz")
      expect(Utils.value_at({ :foo => { :bar => { :bing => 2 } }}, "foo.bar.bing")).to eq(2)
    end

    it "returns nil when the path cannot be followed" do
      expect(Utils.value_at({ :foo => { :bar => :baz }}, "foo.bing")).to be_nil
    end

    it "does not eval" do
      expect {
        Utils.value_at({ :foo => 2 }, "foo[?(@ > 1)]")
      }.to raise_error(RuntimeError, /Cannot use .*? eval/)
    end
  end

  describe "#values_at" do
    it "returns arrays of matching values" do
      expect(Utils.values_at({ :foo => { :bar => :baz }}, "foo.bar")).to eq(%w[baz])
      expect(Utils.values_at({ :foo => [ { :bar => :baz }, { :bar => :bing } ]}, "foo[*].bar")).to eq(%w[baz bing])
      expect(Utils.values_at({ :foo => [ { :bar => :baz }, { :bar => :bing } ]}, "foo[*].bar")).to eq(%w[baz bing])
    end

    it "should allow escaping" do
      expect(Utils.values_at({ :foo => { :bar => "escape this!?" }}, "escape $.foo.bar")).to eq(["escape+this%21%3F"])
    end
  end

  describe "#jsonify" do
    it "escapes </script> tags in the output JSON" do
      cleaned_json = Utils.jsonify(:foo => "bar", :xss => "</script><script>alert('oh no!')</script>")
      expect(cleaned_json).not_to include("</script>")
      expect(cleaned_json).to include('\\u003c/script\\u003e')
    end

    it "html_safes the output unless :skip_safe is passed in" do
      expect(Utils.jsonify({:foo => "bar"})).to be_html_safe
      expect(Utils.jsonify({:foo => "bar"}, :skip_safe => false)).to be_html_safe
      expect(Utils.jsonify({:foo => "bar"}, :skip_safe => true)).not_to be_html_safe
    end
  end

  describe "#pretty_jsonify" do
    it "escapes </script> tags in the output JSON" do
      cleaned_json = Utils.pretty_jsonify(:foo => "bar", :xss => "</script><script>alert('oh no!')</script>")
      expect(cleaned_json).not_to include("</script>")
      expect(cleaned_json).to include("<\\/script>")
    end
  end

  describe "#sort_tuples!" do
    let(:tuples) {
      time = Time.now
      [
        [2, "a", time - 1],  # 0
        [2, "b", time - 1],  # 1
        [1, "b", time - 1],  # 2
        [1, "b", time],      # 3
        [1, "a", time],      # 4
        [2, "a", time + 1],  # 5
        [2, "a", time],      # 6
      ]
    }

    it "sorts tuples like arrays by default" do
      expected = tuples.values_at(4, 2, 3, 0, 6, 5, 1)

      Utils.sort_tuples!(tuples)
      expect(tuples).to eq expected
    end

    it "sorts tuples in order specified: case 1" do
      # order by x1 asc, x2 desc, c3 asc
      orders = [false, true, false]
      expected = tuples.values_at(2, 3, 4, 1, 0, 6, 5)

      Utils.sort_tuples!(tuples, orders)
      expect(tuples).to eq expected
    end

    it "sorts tuples in order specified: case 2" do
      # order by x1 desc, x2 asc, c3 desc
      orders = [true, false, true]
      expected = tuples.values_at(5, 6, 0, 1, 4, 3, 2)

      Utils.sort_tuples!(tuples, orders)
      expect(tuples).to eq expected
    end

    it "always succeeds in sorting even if it finds pairs of incomparable objects" do
      time = Time.now
      tuples = [
        [2,   "a", time - 1],  # 0
        [1,   "b", nil],       # 1
        [1,   "b", time],      # 2
        ["2", nil, time],      # 3
        [1,   nil, time],      # 4
        [nil, "a", time + 1],  # 5
        [2,   "a", time],      # 6
      ]
      orders = [true, false, true]
      expected = tuples.values_at(3, 6, 0, 4, 2, 1, 5)

      Utils.sort_tuples!(tuples, orders)
      expect(tuples).to eq expected
    end
  end

  context "#parse_duration" do
    it "works with correct arguments" do
      expect(Utils.parse_duration('2.days')).to eq(2.days)
      expect(Utils.parse_duration('2.seconds')).to eq(2)
      expect(Utils.parse_duration('2')).to eq(2)
    end

    it "returns nil when passed nil" do
      expect(Utils.parse_duration(nil)).to be_nil
    end

    it "warns and returns nil when not parseable" do
      mock(STDERR).puts("WARNING: Invalid duration format: 'bogus'")
      expect(Utils.parse_duration('bogus')).to be_nil
    end
  end

  context "#if_present" do
    it "returns nil when passed nil" do
      expect(Utils.if_present(nil, :to_i)).to be_nil
    end

    it "calls the specified method when the argument is present" do
      argument = mock()
      mock(argument).to_i { 1 }
      expect(Utils.if_present(argument, :to_i)).to eq(1)
    end
  end
end
