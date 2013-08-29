require 'spec_helper'

describe Agents::HumanTaskAgent do
  before do
    @checker = Agents::HumanTaskAgent.new(:name => "my human task agent")
    @checker.options = @checker.default_options
    @checker.user = users(:bob)
    @checker.save!

    @event = Event.new
    @event.agent = agents(:bob_rain_notifier_agent)
    @event.payload = { :foo => { "bar" => { :baz => "a2b" } },
                       :name => "Joe" }
    @event.id = 345
  end

  describe "when 'trigger_on' is set to 'schedule'" do
    before do
      @checker.options[:trigger_on] = "schedule"
      @checker.options[:submission_period] = "2"
      @checker.options.delete(:expected_receive_period_in_days)
    end

    it "should check for reviewable HITs frequently" do
      mock(@checker).review_hits.twice
      mock(@checker).create_hit.once
      @checker.check
      @checker.check
    end

    it "should create HITs every 'submission_period' hours" do
      now = Time.now
      stub(Time).now { now }
      mock(@checker).review_hits.times(3)
      mock(@checker).create_hit.twice
      @checker.check
      now += 1 * 60 * 60
      @checker.check
      now += 1 * 60 * 60
      @checker.check
    end

    it "should ignore events" do
      mock(@checker).create_hit(anything).times(0)
      @checker.receive([events(:bob_website_agent_event)])
    end
  end

  describe "when 'trigger_on' is set to 'event'" do
    it "should not create HITs during check but should check for reviewable HITs" do
      @checker.options[:submission_period] = "2"
      now = Time.now
      stub(Time).now { now }
      mock(@checker).review_hits.times(3)
      mock(@checker).create_hit.times(0)
      @checker.check
      now += 1 * 60 * 60
      @checker.check
      now += 1 * 60 * 60
      @checker.check
    end

    it "should create HITs based on events" do
      mock(@checker).create_hit(events(:bob_website_agent_event)).times(1)
      @checker.receive([events(:bob_website_agent_event)])
    end
  end

  describe "creating hits" do
    it "can create HITs based on events, interpolating their values" do
      @checker.options[:hit][:title] = "Hi <.name>"
      @checker.options[:hit][:description] = "Make something for <.name>"
      @checker.options[:hit][:questions][0][:name] = "<.name> Question 1"

      question_form = nil
      hitInterface = OpenStruct.new
      hitInterface.id = 123
      mock(hitInterface).question_form(instance_of Agents::HumanTaskAgent::AgentQuestionForm) { |agent_question_form_instance| question_form = agent_question_form_instance }
      mock(RTurk::Hit).create(:title => "Hi Joe").yields(hitInterface) { hitInterface }

      @checker.send :create_hit, @event

      hitInterface.max_assignments.should == @checker.options[:hit][:max_assignments]
      hitInterface.reward.should == @checker.options[:hit][:reward]
      hitInterface.description.should == "Make something for Joe"

      xml = question_form.to_xml
      xml.should include("<Title>Hi Joe</Title>")
      xml.should include("<Text>Make something for Joe</Text>")
      xml.should include("<DisplayName>Joe Question 1</DisplayName>")

      @checker.memory[:hits][123].should == @event.id
    end

    it "works without an event too" do
      @checker.options[:hit][:title] = "Hi <.name>"
      hitInterface = OpenStruct.new
      hitInterface.id = 123
      mock(hitInterface).question_form(instance_of Agents::HumanTaskAgent::AgentQuestionForm)
      mock(RTurk::Hit).create(:title => "Hi").yields(hitInterface) { hitInterface }
      @checker.send :create_hit
      hitInterface.max_assignments.should == @checker.options[:hit][:max_assignments]
      hitInterface.reward.should == @checker.options[:hit][:reward]
    end
  end

  describe "reviewing HITs" do
    class FakeHit
      def initialize(options = {})
        @options = options
      end

      def assignments
        @options[:assignments] || []
      end

      def max_assignments
        @options[:max_assignments] || 1
      end
    end

    class FakeAssignment
      attr_accessor :approved

      def initialize(options = {})
        @options = options
      end

      def answers
        @options[:answers] || {}
      end

      def status
        @options[:status] || ""
      end

      def approve!
        @approved = true
      end
    end

    it "should work on multiple HITs" do
      event2 = Event.new
      event2.agent = agents(:bob_rain_notifier_agent)
      event2.payload = { :foo2 => { "bar2" => { :baz2 => "a2b2" } },
                          :name2 => "Joe2" }
      event2.id = 3452

      # It knows about two HITs from two different events.
      @checker.memory[:hits] = {}
      @checker.memory[:hits][:"JH3132836336DHG"] = @event.id
      @checker.memory[:hits][:"JH39AA63836DHG"] = event2.id

      hit_ids = %w[JH3132836336DHG JH39AA63836DHG JH39AA63836DH12345]
      mock(RTurk::GetReviewableHITs).create { mock!.hit_ids { hit_ids } } # It sees 3 HITs.

      # It looksup the two HITs that it owns.  Neither are ready yet.
      mock(RTurk::Hit).new("JH3132836336DHG") { FakeHit.new }
      mock(RTurk::Hit).new("JH39AA63836DHG") { FakeHit.new }

      @checker.send :review_hits
    end

    it "shouldn't do anything if an assignment isn't ready" do
      @checker.memory[:hits] = { :"JH3132836336DHG" => @event.id }
      mock(RTurk::GetReviewableHITs).create { mock!.hit_ids { %w[JH3132836336DHG JH39AA63836DHG JH39AA63836DH12345] } }
      assignments = [
        FakeAssignment.new(:status => "Accepted", :answers => {}),
        FakeAssignment.new(:status => "Submitted", :answers => {"sentiment"=>"happy", "feedback"=>"Take 2"})
      ]
      hit = FakeHit.new(:max_assignments => 2, :assignments => assignments)
      mock(RTurk::Hit).new("JH3132836336DHG") { hit }

      # One of the assignments isn't set to "Submitted", so this should get skipped for now.
      mock.any_instance_of(FakeAssignment).answers.times(0)

      @checker.send :review_hits

      assignments.all? {|a| a.approved == true }.should be_false
      @checker.memory[:hits].should == { :"JH3132836336DHG" => @event.id }
    end

    it "shouldn't do anything if an assignment is missing" do
      @checker.memory[:hits] = { :"JH3132836336DHG" => @event.id }
      mock(RTurk::GetReviewableHITs).create { mock!.hit_ids { %w[JH3132836336DHG JH39AA63836DHG JH39AA63836DH12345] } }
      assignments = [
        FakeAssignment.new(:status => "Submitted", :answers => {"sentiment"=>"happy", "feedback"=>"Take 2"})
      ]
      hit = FakeHit.new(:max_assignments => 2, :assignments => assignments)
      mock(RTurk::Hit).new("JH3132836336DHG") { hit }

      # One of the assignments hasn't shown up yet, so this should get skipped for now.
      mock.any_instance_of(FakeAssignment).answers.times(0)

      @checker.send :review_hits

      assignments.all? {|a| a.approved == true }.should be_false
      @checker.memory[:hits].should == { :"JH3132836336DHG" => @event.id }
    end

    it "should create events when all assignments are ready" do
      @checker.memory[:hits] = { :"JH3132836336DHG" => @event.id }
      mock(RTurk::GetReviewableHITs).create { mock!.hit_ids { %w[JH3132836336DHG JH39AA63836DHG JH39AA63836DH12345] } }
      assignments = [
        FakeAssignment.new(:status => "Submitted", :answers => {"sentiment"=>"neutral", "feedback"=>""}),
        FakeAssignment.new(:status => "Submitted", :answers => {"sentiment"=>"happy", "feedback"=>"Take 2"})
      ]
      hit = FakeHit.new(:max_assignments => 2, :assignments => assignments)
      mock(RTurk::Hit).new("JH3132836336DHG") { hit }

      lambda {
        @checker.send :review_hits
      }.should change { Event.count }.by(1)

      assignments.all? {|a| a.approved == true }.should be_true

      @checker.events.last.payload[:answers].should == [
        {:sentiment => "neutral", :feedback => ""},
        {:sentiment => "happy", :feedback => "Take 2"}
      ]

      @checker.memory[:hits].should == {}
    end

    describe "taking majority votes" do
      it "should only be valid when all questions are of type 'selection'" do

      end

      it "should take the majority votes of all questions" do

      end
    end
  end
end