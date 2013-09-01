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

    @checker.should be_valid
  end

  describe "validations" do
    it "requires that all questions be of type 'selection' when `take_majority` is `true`" do
      @checker.options[:take_majority] = "true"
      @checker.should_not be_valid
      @checker.options[:hit][:questions][1][:type] = "selection"
      @checker.should be_valid
    end
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
      before do
        @checker.options[:take_majority] = "true"
        @checker.memory[:hits] = { :"JH3132836336DHG" => @event.id }
        mock(RTurk::GetReviewableHITs).create { mock!.hit_ids { %w[JH3132836336DHG JH39AA63836DHG JH39AA63836DH12345] } }
      end

      it "should take the majority votes of all questions" do
        @checker.options[:hit][:questions][1] = {
          :type => "selection",
          :key => "age_range",
          :name => "Age Range",
          :required => "true",
          :question => "Please select your age range:",
          :selections =>
            [
              { :key => "<50", :text => "50 years old or younger" },
              { :key => ">50", :text => "Over 50 years old" }
            ]
        }

        assignments = [
          FakeAssignment.new(:status => "Submitted", :answers => {"sentiment"=>"sad", "age_range"=>"<50"}),
          FakeAssignment.new(:status => "Submitted", :answers => {"sentiment"=>"neutral", "age_range"=>">50"}),
          FakeAssignment.new(:status => "Submitted", :answers => {"sentiment"=>"happy", "age_range"=>">50"}),
          FakeAssignment.new(:status => "Submitted", :answers => {"sentiment"=>"happy", "age_range"=>">50"})
        ]
        hit = FakeHit.new(:max_assignments => 4, :assignments => assignments)
        mock(RTurk::Hit).new("JH3132836336DHG") { hit }

        lambda {
          @checker.send :review_hits
        }.should change { Event.count }.by(1)

        assignments.all? {|a| a.approved == true }.should be_true

        @checker.events.last.payload[:answers].should == [
          { :sentiment => "sad", :age_range => "<50" },
          { :sentiment => "neutral", :age_range => ">50" },
          { :sentiment => "happy", :age_range => ">50" },
          { :sentiment => "happy", :age_range => ">50" }
        ]

        @checker.events.last.payload[:counts].should == { :sentiment => { :happy => 2, :sad => 1, :neutral => 1 }, :age_range => { :">50" => 3, :"<50" => 1 } }
        @checker.events.last.payload[:majority_answer].should == { :sentiment => "happy", :age_range => ">50" }
        @checker.events.last.payload.should_not have_key(:average_answer)

        @checker.memory[:hits].should == {}
      end

      it "should also provide an average answer when all questions are numeric" do
        @checker.options[:hit][:questions] = [
          {
            :type => "selection",
            :key => "rating",
            :name => "Rating",
            :required => "true",
            :question => "Please select a rating:",
            :selections =>
              [
                { :key => "1", :text => "One" },
                { :key => "2", :text => "Two" },
                { :key => "3", :text => "Three" },
                { :key => "4", :text => "Four" },
                { :key => "5.1", :text => "Five Point One" }
              ]
          }
        ]

        assignments = [
          FakeAssignment.new(:status => "Submitted", :answers => { "rating"=>"1" }),
          FakeAssignment.new(:status => "Submitted", :answers => { "rating"=>"3" }),
          FakeAssignment.new(:status => "Submitted", :answers => { "rating"=>"5.1" }),
          FakeAssignment.new(:status => "Submitted", :answers => { "rating"=>"2" }),
          FakeAssignment.new(:status => "Submitted", :answers => { "rating"=>"2" })
        ]
        hit = FakeHit.new(:max_assignments => 5, :assignments => assignments)
        mock(RTurk::Hit).new("JH3132836336DHG") { hit }

        lambda {
          @checker.send :review_hits
        }.should change { Event.count }.by(1)

        assignments.all? {|a| a.approved == true }.should be_true

        @checker.events.last.payload[:answers].should == [
          { :rating => "1" },
          { :rating => "3" },
          { :rating => "5.1" },
          { :rating => "2" },
          { :rating => "2" }
        ]

        @checker.events.last.payload[:counts].should == { :rating => { :"1" => 1, :"2" => 2, :"3" => 1, :"4" => 0, :"5.1" => 1 } }
        @checker.events.last.payload[:majority_answer].should == { :rating => "2" }
        @checker.events.last.payload[:average_answer].should == { :rating => (1 + 2 + 2 + 3 + 5.1) / 5.0 }

        @checker.memory[:hits].should == {}
      end
    end
  end
end