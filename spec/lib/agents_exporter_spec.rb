# encoding: utf-8

require 'spec_helper'

describe AgentsExporter do
  describe "#as_json" do
    let(:name) { "My set of Agents" }
    let(:description) { "These Agents work together nicely!" }
    let(:guid) { "some-guid" }
    let(:tag_fg_color) { "#ffffff" }
    let(:tag_bg_color) { "#000000" }
    let(:source_url) { "http://yourhuginn.com/scenarios/2/export.json" }
    let(:agent_list) { [agents(:jane_weather_agent), agents(:jane_rain_notifier_agent)] }
    let(:exporter) { AgentsExporter.new(
      :agents => agent_list, :name => name, :description => description, :source_url => source_url,
      :guid => guid, :tag_fg_color => tag_fg_color, :tag_bg_color => tag_bg_color) }

    it "outputs a structure containing name, description, the date, all agents & their links" do
      data = exporter.as_json
      data[:name].should == name
      data[:description].should == description
      data[:source_url].should == source_url
      data[:guid].should == guid
      data[:tag_fg_color].should == tag_fg_color
      data[:tag_bg_color].should == tag_bg_color
      Time.parse(data[:exported_at]).should be_within(2).of(Time.now.utc)
      data[:links].should == [{ :source => 0, :receiver => 1 }]
      data[:agents].should == agent_list.map { |agent| exporter.agent_as_json(agent) }
      data[:agents].all? { |agent_json| agent_json[:guid].present? && agent_json[:type].present? && agent_json[:name].present? }.should be_truthy

      data[:agents][0].should_not have_key(:propagate_immediately) # can't receive events
      data[:agents][1].should_not have_key(:schedule) # can't be scheduled
    end

    it "does not output links to other agents outside of the incoming set" do
      Link.create!(:source_id => agents(:jane_weather_agent).id, :receiver_id => agents(:jane_website_agent).id)
      Link.create!(:source_id => agents(:jane_website_agent).id, :receiver_id => agents(:jane_rain_notifier_agent).id)

      exporter.as_json[:links].should == [{ :source => 0, :receiver => 1 }]
    end
  end

  describe "#filename" do
    it "strips special characters" do
      AgentsExporter.new(:name => "ƏfooƐƕƺbar").filename.should == "foo-bar.json"
    end

    it "strips punctuation" do
      AgentsExporter.new(:name => "foo,bar").filename.should == "foo-bar.json"
    end

    it "strips leading and trailing dashes" do
      AgentsExporter.new(:name => ",foo,").filename.should == "foo.json"
    end

    it "has a default when options[:name] is nil" do
      AgentsExporter.new(:name => nil).filename.should == "exported-agents.json"
    end

    it "has a default when the result is empty" do
      AgentsExporter.new(:name => "").filename.should == "exported-agents.json"
      AgentsExporter.new(:name => "Ə").filename.should == "exported-agents.json"
      AgentsExporter.new(:name => "-").filename.should == "exported-agents.json"
      AgentsExporter.new(:name => ",,").filename.should == "exported-agents.json"
    end
  end
end
