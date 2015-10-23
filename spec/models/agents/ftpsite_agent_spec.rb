require 'rails_helper'
require 'time'

describe Agents::FtpsiteAgent do
  describe "checking anonymous FTP" do
    before do
      @site = {
        'expected_update_period_in_days' => 1,
        'url' => "ftp://ftp.example.org/pub/releases/",
        'patterns' => ["example*.tar.gz"],
      }
      @checker = Agents::FtpsiteAgent.new(:name => "Example", :options => @site, :keep_events_for => 2.days)
      @checker.user = users(:bob)
      @checker.save!
    end

    describe "#check" do

      before do
        stub(@checker).each_entry.returns { |block|
          block.call("example latest.tar.gz", Time.parse("2014-04-01T10:00:01Z"))
          block.call("example-1.0.tar.gz",    Time.parse("2013-10-01T10:00:00Z"))
          block.call("example-1.1.tar.gz",    Time.parse("2014-04-01T10:00:00Z"))
        }
      end

      it "should validate the integer fields" do
        @checker.options['expected_update_period_in_days'] = "nonsense"
        expect { @checker.save! }.to raise_error(/Invalid expected_update_period_in_days format/);
        @checker.options = @site
      end

      it "should check for changes and save known entries in memory" do
        expect { @checker.check }.to change { Event.count }.by(3)
        @checker.memory['known_entries'].tap { |known_entries|
          expect(known_entries.size).to eq(3)
          expect(known_entries.sort_by(&:last)).to eq([
            ["example-1.0.tar.gz",    "2013-10-01T10:00:00Z"],
            ["example-1.1.tar.gz",    "2014-04-01T10:00:00Z"],
            ["example latest.tar.gz", "2014-04-01T10:00:01Z"],
          ])
        }

        expect(Event.last(2).first.payload).to eq({
          'url' => 'ftp://ftp.example.org/pub/releases/example-1.1.tar.gz',
          'filename' => 'example-1.1.tar.gz',
          'timestamp' => '2014-04-01T10:00:00Z',
        })

        expect { @checker.check }.not_to change { Event.count }

        stub(@checker).each_entry.returns { |block|
          block.call("example latest.tar.gz", Time.parse("2014-04-02T10:00:01Z"))

          # In the long list format the timestamp may look going
          # backwards after six months: Oct 01 10:00 -> Oct 01 2013
          block.call("example-1.0.tar.gz",    Time.parse("2013-10-01T00:00:00Z"))

          block.call("example-1.1.tar.gz",    Time.parse("2014-04-01T10:00:00Z"))
          block.call("example-1.2.tar.gz",    Time.parse("2014-04-02T10:00:00Z"))
        }
        expect { @checker.check }.to change { Event.count }.by(2)
        @checker.memory['known_entries'].tap { |known_entries|
          expect(known_entries.size).to eq(4)
          expect(known_entries.sort_by(&:last)).to eq([
            ["example-1.0.tar.gz",    "2013-10-01T00:00:00Z"],
            ["example-1.1.tar.gz",    "2014-04-01T10:00:00Z"],
            ["example-1.2.tar.gz",    "2014-04-02T10:00:00Z"],
            ["example latest.tar.gz", "2014-04-02T10:00:01Z"],
          ])
        }

        expect(Event.last(2).first.payload).to eq({
          'url' => 'ftp://ftp.example.org/pub/releases/example-1.2.tar.gz',
          'filename' => 'example-1.2.tar.gz',
          'timestamp' => '2014-04-02T10:00:00Z',
        })

        expect(Event.last.payload).to eq({
          'url' => 'ftp://ftp.example.org/pub/releases/example%20latest.tar.gz',
          'filename' => 'example latest.tar.gz',
          'timestamp' => '2014-04-02T10:00:01Z',
        })

        expect { @checker.check }.not_to change { Event.count }
      end
    end

    describe "#each_entry" do
      before do
        stub.any_instance_of(Net::FTP).list.returns [ # Windows format
          "04-02-14  10:01AM            288720748 example latest.tar.gz",
          "04-01-14  10:05AM            288720710 no-match-example.tar.gz"
        ]
        stub(@checker).open_ftp.yields Net::FTP.new
      end

      it "filters out files that don't match the given format" do
        entries = []
        @checker.each_entry { |a, b| entries.push [a, b] }

        expect(entries.size).to eq(1)
        filename, mtime = entries.first
        expect(filename).to eq('example latest.tar.gz')
        expect(mtime).to eq('2014-04-02T10:01:00Z')
      end

      it "filters out files that are older than the given date" do
        @checker.options['after'] = '2015-10-21'
        entries = []
        @checker.each_entry { |a, b| entries.push [a, b] }
        expect(entries.size).to eq(0)
      end
    end

  end
end
