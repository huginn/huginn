require 'spec_helper'

describe LiquidMigrator do
  describe "converting JSONPath strings" do
    it "should work" do
      LiquidMigrator.convert_string("$.data", true).should == "{{data}}"
      LiquidMigrator.convert_string("$.data.test", true).should == "{{data.test}}"
      LiquidMigrator.convert_string("$.data.test.*", true).should == "{{data.test}}"
    end

    it "should ignore strings which just contain a JSONPath" do
      LiquidMigrator.convert_string("$.data").should == "$.data"
      LiquidMigrator.convert_string(" $.data", true).should == " $.data"
      LiquidMigrator.convert_string("lorem $.data", true).should == "lorem $.data"
    end
  end

  describe "converting escaped JSONPath strings" do
    it "should work" do
      LiquidMigrator.convert_string("Received <$.content.text.*> from <$.content.name> .").should ==
                                    "Received {{content.text}} from {{content.name}} ."
      LiquidMigrator.convert_string("Weather looks like <$.conditions> according to the forecast at <$.pretty_date.time>").should ==
                                    "Weather looks like {{conditions}} according to the forecast at {{pretty_date.time}}"
    end

    it "should convert the 'escape' method correctly" do
      LiquidMigrator.convert_string("Escaped: <escape $.content.name>\nNot escaped: <$.content.name>").should ==
                                    "Escaped: {{content.name | uri_escape}}\nNot escaped: {{content.name}}"
    end
  end

  describe "migrating a hash" do
    it "should convert every attribute" do
      LiquidMigrator.convert_hash({'a' => "$.data", 'b' => "This is a <$.test>"}).should ==
                                  {'a' => "$.data", 'b' => "This is a {{test}}"}
    end
    it "should work with leading_dollarsign_is_jsonpath" do
      LiquidMigrator.convert_hash({'a' => "$.data", 'b' => "This is a <$.test>"}, leading_dollarsign_is_jsonpath: true).should ==
                                  {'a' => "{{data}}", 'b' => "This is a {{test}}"}
    end
    it "should use the corresponding *_path attributes when using merge_path_attributes"do
      LiquidMigrator.convert_hash({'a' => "default", 'a_path' => "$.data"}, {leading_dollarsign_is_jsonpath: true, merge_path_attributes: true}).should ==
                                  {'a' => "{{data}}"}
    end
  end

  describe "migrating an actual agent" do
    before do
      valid_params = {
                        'auth_token' => 'token',
                        'room_name' => 'test',
                        'room_name_path' => '',
                        'username' => "Huginn",
                        'username_path' => '$.username',
                        'message' => "Hello from Huginn!",
                        'message_path' => '$.message',
                        'notify' => false,
                        'notify_path' => '',
                        'color' => 'yellow',
                        'color_path' => '',
                      }

      @agent = Agents::HipchatAgent.new(:name => "somename", :options => valid_params)
      @agent.user = users(:jane)
      @agent.save!
    end

    it "should work" do
      LiquidMigrator.convert_all_agent_options(@agent)
      @agent.reload.options.should == {"auth_token" => 'token', 'color' => 'yellow', 'notify' => false, 'room_name' => 'test', 'username' => '{{username}}', 'message' => '{{message}}'}
    end
  end
end