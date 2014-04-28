require 'spec_helper'

describe DotHelper do
  describe "#dot_id" do
    it "properly escapes double quotaion and backslash" do
      dot_id('hello\\"').should == '"hello\\\\\\""'
    end
  end

  describe "with example Agents" do
    class Agents::DotFoo < Agent
      default_schedule "2pm"

      def check
        create_event :payload => {}
      end
    end

    class Agents::DotBar < Agent
      cannot_be_scheduled!

      def check
        create_event :payload => {}
      end
    end

    before do
      stub(Agents::DotFoo).valid_type?("Agents::DotFoo") { true }
      stub(Agents::DotBar).valid_type?("Agents::DotBar") { true }
    end

    describe "#agents_dot" do
      it "generates a DOT script" do
        @foo = Agents::DotFoo.new(:name => "foo")
        @foo.user = users(:bob)
        @foo.save!

        @bar = Agents::DotBar.new(:name => "bar")
        @bar.user = users(:bob)
        @bar.sources << @foo
        @bar.save!

        agents_dot([@foo, @bar]).should == 'digraph foo {"foo";"foo"->"bar";"bar";}'
        agents_dot([@foo, @bar], true).should == 'digraph foo {"foo"[URL="/agents/%d"];"foo"->"bar";"bar"[URL="/agents/%d"];}' % [@foo.id, @bar.id]
      end
    end
  end
end
