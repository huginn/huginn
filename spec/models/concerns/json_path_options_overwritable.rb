require 'spec_helper'

shared_examples_for JsonPathOptionsOverwritable do
  before(:each) do
    @valid_params = described_class.new.default_options

    @checker = described_class.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)

    @event = Event.new
    @event.agent = agents(:bob_weather_agent)
    @event.payload = { :room_name => 'test room', :message => 'Looks like its going to rain', username: "Huggin user"}
    @event.save!
  end

  describe "select_option" do
    it "should use the room_name_path if specified" do
      @checker.options['room_name_path'] = "$.room_name"
      @checker.send(:select_option, @event, :room_name).should == "test room"
    end

    it "should use the normal option when the path option is blank" do
      @checker.options['room_name'] = 'test'
      @checker.send(:select_option, @event, :room_name).should == "test"
    end
  end

  it "should merge all options" do
    @checker.send(:merge_json_path_options, @event).symbolize_keys.keys.should == @checker.send(:options_with_path)
  end
end
