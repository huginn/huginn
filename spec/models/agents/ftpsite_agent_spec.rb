require 'spec_helper'
require 'time'

describe Agents::FtpsiteAgent do
  describe "checking anonymous FTP" do
    before do
      @site = {
        'expected_update_period_in_days' => 1,
        'url' => "ftp://ftp.example.org/pub/releases/",
        'patterns' => ["example-*.tar.gz"],
      }
      @checker = Agents::FtpsiteAgent.new(:name => "Example", :options => @site, :keep_events_for => 2)
      @checker.user = users(:bob)
      @checker.save!
      stub(@checker).each_entry.returns { |block|
        block.call("example-latest.tar.gz", Time.parse("2014-04-01T10:00:01Z"))
        block.call("example-1.0.tar.gz",    Time.parse("2013-10-01T10:00:00Z"))
        block.call("example-1.1.tar.gz",    Time.parse("2014-04-01T10:00:00Z"))
      }
    end

    describe "#check" do
      it "should validate the integer fields" do
        @checker.options['expected_update_period_in_days'] = "nonsense"
        lambda { @checker.save! }.should raise_error;
        @checker.options = @site
      end

      it "should check for changes and save known entries in memory" do
        lambda { @checker.check }.should change { Event.count }.by(3)
        @checker.memory['known_entries'].tap { |known_entries|
          known_entries.size.should == 3
          known_entries.sort_by(&:last).should == [
            ["example-1.0.tar.gz",    "2013-10-01T10:00:00Z"],
            ["example-1.1.tar.gz",    "2014-04-01T10:00:00Z"],
            ["example-latest.tar.gz", "2014-04-01T10:00:01Z"],
          ]
        }

        Event.last(2).first.payload.should == {
          'url' => 'ftp://ftp.example.org/pub/releases/example-1.1.tar.gz',
          'filename' => 'example-1.1.tar.gz',
          'timestamp' => '2014-04-01T10:00:00Z',
        }

        lambda { @checker.check }.should_not change { Event.count }

        stub(@checker).each_entry.returns { |block|
          block.call("example-latest.tar.gz", Time.parse("2014-04-02T10:00:01Z"))

          # In the long list format the timestamp may look going
          # backwards after six months: Oct 01 10:00 -> Oct 01 2013
          block.call("example-1.0.tar.gz",    Time.parse("2013-10-01T00:00:00Z"))

          block.call("example-1.1.tar.gz",    Time.parse("2014-04-01T10:00:00Z"))
          block.call("example-1.2.tar.gz",    Time.parse("2014-04-02T10:00:00Z"))
        }
        lambda { @checker.check }.should change { Event.count }.by(2)
        @checker.memory['known_entries'].tap { |known_entries|
          known_entries.size.should == 4
          known_entries.sort_by(&:last).should == [
            ["example-1.0.tar.gz",    "2013-10-01T00:00:00Z"],
            ["example-1.1.tar.gz",    "2014-04-01T10:00:00Z"],
            ["example-1.2.tar.gz",    "2014-04-02T10:00:00Z"],
            ["example-latest.tar.gz", "2014-04-02T10:00:01Z"],
          ]
        }

        Event.last(2).first.payload.should == {
          'url' => 'ftp://ftp.example.org/pub/releases/example-1.2.tar.gz',
          'filename' => 'example-1.2.tar.gz',
          'timestamp' => '2014-04-02T10:00:00Z',
        }

        lambda { @checker.check }.should_not change { Event.count }
      end
    end
  end
end
