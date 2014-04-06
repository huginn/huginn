require 'spec_helper'

describe Utils do
  describe "#unindent" do
    it "unindents to the level of the greatest consistant indention" do
      Utils.unindent(<<-MD).should == "Hello World"
        Hello World
      MD

      Utils.unindent(<<-MD).should == "Hello World\nThis is\nnot indented"
        Hello World
        This is
        not indented
      MD

      Utils.unindent(<<-MD).should == "Hello World\n  This is\n  indented\nthough"
        Hello World
          This is
          indented
        though
      MD

      Utils.unindent("Hello\n  I am indented").should == "Hello\n  I am indented"

      a = "        Events will have the fields you specified.  Your options look like:\n\n            {\n      \"url\": {\n        \"css\": \"#comic img\",\n        \"attr\": \"src\"\n      },\n      \"title\": {\n        \"css\": \"#comic img\",\n        \"attr\": \"title\"\n      }\n    }\"\n"
      Utils.unindent(a).should == "Events will have the fields you specified.  Your options look like:\n\n    {\n      \"url\": {\n\"css\": \"#comic img\",\n\"attr\": \"src\"\n      },\n      \"title\": {\n\"css\": \"#comic img\",\n\"attr\": \"title\"\n      }\n    }\""
    end
  end

  describe "#interpolate_jsonpaths" do
    let(:payload) { { :there => { :world => "WORLD" }, :works => "should work" } }

    it "interpolates jsonpath expressions between matching <>'s" do
      Utils.interpolate_jsonpaths("hello <$.there.world> this <escape works>", payload).should == "hello WORLD this should+work"
    end

    it "optionally supports treating values that start with '$' as raw JSONPath" do
      Utils.interpolate_jsonpaths("$.there.world", payload).should == "$.there.world"
      Utils.interpolate_jsonpaths("$.there.world", payload, :leading_dollarsign_is_jsonpath => true).should == "WORLD"
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
      Utils.recursively_interpolate_jsonpaths(struct, data).should == {
        :int => 5,
        :string => "this should+work",
        :array => ["should work", "now", "WORLD"],
        :deep => {
          :string => "hello WORLD",
          :hello => :world
        }
      }
    end
  end

  describe "#value_at" do
    it "returns the value at a JSON path" do
      Utils.value_at({ :foo => { :bar => :baz }}.to_json, "foo.bar").should == "baz"
      Utils.value_at({ :foo => { :bar => { :bing => 2 } }}, "foo.bar.bing").should == 2
    end

    it "returns nil when the path cannot be followed" do
      Utils.value_at({ :foo => { :bar => :baz }}, "foo.bing").should be_nil
    end

    it "does not eval" do
      lambda {
        Utils.value_at({ :foo => 2 }, "foo[?(@ > 1)]")
      }.should raise_error(RuntimeError, /Cannot use .*? eval/)
    end
  end

  describe "#values_at" do
    it "returns arrays of matching values" do
      Utils.values_at({ :foo => { :bar => :baz }}, "foo.bar").should == %w[baz]
      Utils.values_at({ :foo => [ { :bar => :baz }, { :bar => :bing } ]}, "foo[*].bar").should == %w[baz bing]
      Utils.values_at({ :foo => [ { :bar => :baz }, { :bar => :bing } ]}, "foo[*].bar").should == %w[baz bing]
    end

    it "should allow escaping" do
      Utils.values_at({ :foo => { :bar => "escape this!?" }}, "escape $.foo.bar").should == ["escape+this%21%3F"]
    end
  end

  describe "#jsonify" do
    it "escapes </script> tags in the output JSON" do
      cleaned_json = Utils.jsonify(:foo => "bar", :xss => "</script><script>alert('oh no!')</script>")
      cleaned_json.should_not include("</script>")
      cleaned_json.should include("<\\/script>")
    end

    it "html_safes the output unless :skip_safe is passed in" do
      Utils.jsonify({:foo => "bar"}).should be_html_safe
      Utils.jsonify({:foo => "bar"}, :skip_safe => false).should be_html_safe
      Utils.jsonify({:foo => "bar"}, :skip_safe => true).should_not be_html_safe
    end
  end

  describe "#pretty_jsonify" do
    it "escapes </script> tags in the output JSON" do
      cleaned_json = Utils.pretty_jsonify(:foo => "bar", :xss => "</script><script>alert('oh no!')</script>")
      cleaned_json.should_not include("</script>")
      cleaned_json.should include("<\\/script>")
    end
  end
end