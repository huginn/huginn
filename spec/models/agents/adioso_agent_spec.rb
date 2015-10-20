require 'rails_helper'

describe Agents::AdiosoAgent do
	before do
		stub_request(:get, /parse/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/adioso_parse.json")), :status => 200, :headers => {"Content-Type" => "text/json"})
		stub_request(:get, /fares/).to_return(:body => File.read(Rails.root.join("spec/data_fixtures/adioso_fare.json")),  :status => 200, :headers => {"Content-Type" => "text/json"})
		@valid_params = {
											:start_date => "June 25 2013",
											:end_date   => "July 15 2013",
											:from       => "Portland",
											:to         => "Chicago",
											:username   => "xx",
											:password   => "xx",
											:expected_update_period_in_days => "2"
										}

		@checker = Agents::AdiosoAgent.new(:name => "somename", :options => @valid_params)
		@checker.user = users(:jane)
		@checker.save!
	end

	describe "#check" do
		it "should check that initial run creates an event" do
			expect { @checker.check }.to change { Event.count }.by(1)
		end
	end

	describe "#working?" do
		it "checks if its generating events as scheduled" do
			expect(@checker).not_to be_working
			@checker.check
			expect(@checker.reload).to be_working
			three_days_from_now = 3.days.from_now
			stub(Time).now { three_days_from_now }
			expect(@checker).not_to be_working
		end
	end
end
