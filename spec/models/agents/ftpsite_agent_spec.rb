require 'rails_helper'
require 'time'

describe Agents::FtpsiteAgent do
  describe "checking anonymous FTP" do
    before do
      @site = {
        'expected_update_period_in_days' => 1,
        'url' => "ftp://ftp.example.org/pub/releases/",
        'patterns' => ["example*.tar.gz"],
        'mode' => 'read',
        'filename' => 'test',
        'data' => '{{ data }}'
      }
      @checker = Agents::FtpsiteAgent.new(:name => "Example", :options => @site, :keep_events_for => 2.days)
      @checker.user = users(:bob)
      @checker.save!
    end

    context "#validate_options" do
      it "requires url to be a valid URI" do
        @checker.options['url'] = 'not_valid'
        expect(@checker).not_to be_valid
      end

      it "allows an URI without a path" do
        @checker.options['url'] = 'ftp://ftp.example.org'
        expect(@checker).to be_valid
      end

      it "does not check the url when liquid output markup is used" do
        @checker.options['url'] = 'ftp://{{ ftp_host }}'
        expect(@checker).to be_valid
      end

      it "requires patterns to be present and not empty array" do
        @checker.options['patterns'] = ''
        expect(@checker).not_to be_valid
        @checker.options['patterns'] = 'not an array'
        expect(@checker).not_to be_valid
        @checker.options['patterns'] = []
        expect(@checker).not_to be_valid
      end

      it "when present timestamp must be parsable into a Time object instance" do
        @checker.options['timestamp'] = '2015-01-01 00:00:01'
        expect(@checker).to be_valid
        @checker.options['timestamp'] = 'error'
        expect(@checker).not_to be_valid
      end

      it "requires mode to be set to 'read' or 'write'" do
        @checker.options['mode'] = 'write'
        expect(@checker).to be_valid
        @checker.options['mode'] = ''
        expect(@checker).not_to be_valid
      end

      it 'automatically sets mode to read when the agent is a new record' do
        checker = Agents::FtpsiteAgent.new(name: 'test', options: @site.except('mode'))
        checker.user = users(:bob)
        expect(checker).to be_valid
        expect(checker.options['mode']).to eq('read')
      end

      it "requires 'filename' in 'write' mode" do
        @checker.options['mode'] = 'write'
        @checker.options['filename'] = ''
        expect(@checker).not_to be_valid
      end

      it "requires 'data' in 'write' mode" do
        @checker.options['mode'] = 'write'
        @checker.options['data'] = ''
        expect(@checker).not_to be_valid
      end
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
          'file_pointer' => { 'file' => 'example-1.1.tar.gz', 'agent_id' => @checker.id },
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
          'file_pointer' => { 'file' => 'example-1.2.tar.gz', 'agent_id' => @checker.id },
          'url' => 'ftp://ftp.example.org/pub/releases/example-1.2.tar.gz',
          'filename' => 'example-1.2.tar.gz',
          'timestamp' => '2014-04-02T10:00:00Z',
        })

        expect(Event.last.payload).to eq({
          'file_pointer' => { 'file' => 'example latest.tar.gz', 'agent_id' => @checker.id },
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

    context "#open_ftp" do
      before(:each) do
        @ftp_mock = mock()
        mock(@ftp_mock).close
        mock(@ftp_mock).connect('ftp.example.org', 21)
        mock(@ftp_mock).passive=(true)
        mock(Net::FTP).new { @ftp_mock }
      end
      context 'with_path' do
        before(:each) { mock(@ftp_mock).chdir('pub/releases') }

        it "logs in as anonymous when no user and password are given" do
          mock(@ftp_mock).login('anonymous', 'anonymous@')
          expect { |b| @checker.open_ftp(@checker.base_uri, &b) }.to yield_with_args(@ftp_mock)
        end

        it "passes the provided user and password" do
          @checker.options['url'] = "ftp://user:password@ftp.example.org/pub/releases/"
          mock(@ftp_mock).login('user', 'password')
          expect { |b| @checker.open_ftp(@checker.base_uri, &b) }.to yield_with_args(@ftp_mock)
        end
      end

      it "does not call chdir when no path is given" do
        @checker.options['url'] = "ftp://ftp.example.org/"
        mock(@ftp_mock).login('anonymous', 'anonymous@')
        expect { |b| @checker.open_ftp(@checker.base_uri, &b) }.to yield_with_args(@ftp_mock)
      end
    end

    context "#get_io" do
      it "returns the contents of the file" do
        ftp_mock= mock()
        mock(ftp_mock).getbinaryfile('file', nil).yields('data')
        mock(@checker).open_ftp(@checker.base_uri).yields(ftp_mock)
        expect(@checker.get_io('file').read).to eq('data')
      end

      it "uses the encoding specified in force_encoding to convert the data to UTF-8" do
        ftp_mock= mock()
        mock(ftp_mock).getbinaryfile('file', nil).yields('ümlaut'.force_encoding('ISO-8859-15'))
        mock(@checker).open_ftp(@checker.base_uri).yields(ftp_mock)
        expect(@checker.get_io('file').read).to eq('ümlaut')
      end

      it "returns an empty StringIO instance when no data was read" do
        ftp_mock= mock()
        mock(ftp_mock).getbinaryfile('file', nil)
        mock(@checker).open_ftp(@checker.base_uri).yields(ftp_mock)
        expect(@checker.get_io('file').length).to eq(0)
      end
    end

    context "#receive" do
      before(:each) do
        @checker.options['mode'] = 'write'
        @checker.options['filename'] = 'file.txt'
        @checker.options['data'] = '{{ data }}'
        @ftp_mock= mock()
        @stringio = StringIO.new()
        mock(@checker).open_ftp(@checker.base_uri).yields(@ftp_mock)
      end

      it "writes the data at data into a file" do
        mock(StringIO).new('hello world🔥') { @stringio }
        mock(@ftp_mock).storbinary('STOR file.txt', @stringio, Net::FTP::DEFAULT_BLOCKSIZE)
        event = Event.new(payload: {'data' => 'hello world🔥'})
        @checker.receive([event])
      end

      it "converts the string encoding when force_encoding is specified" do
        @checker.options['force_encoding'] = 'ISO-8859-1'
        mock(StringIO).new('hello world?') { @stringio }
        mock(@ftp_mock).storbinary('STOR file.txt', @stringio, Net::FTP::DEFAULT_BLOCKSIZE)
        event = Event.new(payload: {'data' => 'hello world🔥'})
        @checker.receive([event])
      end
    end
  end
end
