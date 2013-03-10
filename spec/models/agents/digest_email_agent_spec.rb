require 'spec_helper'

describe Agents::DigestEmailAgent do
  def get_message_part(mail, content_type)
    mail.body.parts.find { |p| p.content_type.match content_type }.body.raw_source
  end

  before do
    @checker = Agents::DigestEmailAgent.new(:name => "something", :options => { :expected_receive_period_in_days => 2, :subject => "something interesting" })
    @checker.user = users(:bob)
    @checker.save!
  end

  describe "#receive" do
    it "queues any payloads it receives" do
      event1 = Event.new
      event1.agent = agents(:bob_rain_notifier_agent)
      event1.payload = "Something you should know about"
      event1.save!

      event2 = Event.new
      event2.agent = agents(:bob_weather_agent)
      event2.payload = "Something else you should know about"
      event2.save!

      @checker.async_receive([event1.id, event2.id])
      @checker.reload.memory[:queue].should == ["Something you should know about", "Something else you should know about"]
    end
  end

  describe "#check" do
    it "should send an email" do
      @checker.async_check
      ActionMailer::Base.deliveries.should == []

      @checker.memory[:queue] = ["Something you should know about", { :title => "Foo", :url => "http://google.com", :bar => 2 }, { "message" => "hi", :woah => "there" }]
      @checker.save!

      @checker.async_check
      ActionMailer::Base.deliveries.last.to.should == ["bob@example.com"]
      ActionMailer::Base.deliveries.last.subject.should == "something interesting"
      get_message_part(ActionMailer::Base.deliveries.last, /plain/).strip.should == "Something you should know about\n\nFoo (bar: 2 and url: http://google.com)\n\nhi (woah: there)"
      @checker.reload.memory[:queue].should == []
    end
  end
end