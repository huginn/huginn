require 'rails_helper'

describe AgentsExporter do
  describe "#as_json" do
    let(:name) { "My set of Agents" }
    let(:description) { "These Agents work together nicely!" }
    let(:guid) { "some-guid" }
    let(:tag_fg_color) { "#ffffff" }
    let(:tag_bg_color) { "#000000" }
    let(:icon) { 'Camera' }
    let(:source_url) { "http://yourhuginn.com/scenarios/2/export.json" }
    let(:agent_list) { [agents(:jane_weather_agent), agents(:jane_rain_notifier_agent)] }
    let(:exporter) { AgentsExporter.new(
      agents: agent_list, name: name, description: description,
      source_url: source_url, guid: guid, tag_fg_color: tag_fg_color,
      tag_bg_color: tag_bg_color, icon: icon) }

    it "outputs a structure containing name, description, the date, all agents & their links" do
      data = exporter.as_json
      expect(data[:name]).to eq(name)
      expect(data[:description]).to eq(description)
      expect(data[:source_url]).to eq(source_url)
      expect(data[:guid]).to eq(guid)
      expect(data[:schema_version]).to eq(1)
      expect(data[:tag_fg_color]).to eq(tag_fg_color)
      expect(data[:tag_bg_color]).to eq(tag_bg_color)
      expect(data[:icon]).to eq(icon)
      expect(Time.parse(data[:exported_at])).to be_within(2).of(Time.now.utc)
      expect(data[:links]).to eq([{ :source => guid_order(agent_list, :jane_weather_agent), :receiver => guid_order(agent_list, :jane_rain_notifier_agent)}])
      expect(data[:control_links]).to eq([])
      expect(data[:agents]).to eq(agent_list.sort_by{|a| a.guid}.map { |agent| exporter.agent_as_json(agent) })
      expect(data[:agents].all? { |agent_json| agent_json[:guid].present? && agent_json[:type].present? && agent_json[:name].present? }).to be_truthy

      expect(data[:agents][guid_order(agent_list, :jane_weather_agent)]).not_to have_key(:propagate_immediately) # can't receive events
      expect(data[:agents][guid_order(agent_list, :jane_rain_notifier_agent)]).not_to have_key(:schedule) # can't be scheduled
    end

    it "does not output links to other agents outside of the incoming set" do
      Link.create!(:source_id => agents(:jane_weather_agent).id, :receiver_id => agents(:jane_website_agent).id)
      Link.create!(:source_id => agents(:jane_website_agent).id, :receiver_id => agents(:jane_rain_notifier_agent).id)

      expect(exporter.as_json[:links]).to eq([{ :source => guid_order(agent_list, :jane_weather_agent), :receiver => guid_order(agent_list, :jane_rain_notifier_agent) }])
    end

    it "outputs control links to agents within the incoming set, but not outside it" do
      agents(:jane_rain_notifier_agent).control_targets = [agents(:jane_weather_agent), agents(:jane_basecamp_agent)]
      agents(:jane_rain_notifier_agent).save!

      expect(exporter.as_json[:control_links]).to eq([{ :controller => guid_order(agent_list, :jane_rain_notifier_agent), :control_target => guid_order(agent_list, :jane_weather_agent) }])
    end
  end

  describe "#filename" do
    it "strips special characters" do
      expect(AgentsExporter.new(:name => "ƏfooƐƕƺbar").filename).to eq("foo-bar.json")
    end

    it "strips punctuation" do
      expect(AgentsExporter.new(:name => "foo,bar").filename).to eq("foo-bar.json")
    end

    it "strips leading and trailing dashes" do
      expect(AgentsExporter.new(:name => ",foo,").filename).to eq("foo.json")
    end

    it "has a default when options[:name] is nil" do
      expect(AgentsExporter.new(:name => nil).filename).to eq("exported-agents.json")
    end

    it "has a default when the result is empty" do
      expect(AgentsExporter.new(:name => "").filename).to eq("exported-agents.json")
      expect(AgentsExporter.new(:name => "Ə").filename).to eq("exported-agents.json")
      expect(AgentsExporter.new(:name => "-").filename).to eq("exported-agents.json")
      expect(AgentsExporter.new(:name => ",,").filename).to eq("exported-agents.json")
    end
  end

  def guid_order(agent_list, agent_name)
    agent_list.map{|a|a.guid}.sort.find_index(agents(agent_name).guid)
  end
end
