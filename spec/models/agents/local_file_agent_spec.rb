require 'rails_helper'

describe Agents::LocalFileAgent do
  before(:each) do
    @valid_params = {
                      'mode' => 'read',
                      'watch' => 'false',
                      'append' => 'false',
                      'path' => File.join(Rails.root, 'tmp', 'spec')
                    }
    FileUtils.mkdir_p File.join(Rails.root, 'tmp', 'spec')

    @checker = Agents::LocalFileAgent.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!
  end

  after(:all) do
    FileUtils.rm_r File.join(Rails.root, 'tmp', 'spec')
  end

  describe "#validate_options" do
    it "is valid with the given options" do
      expect(@checker).to be_valid
    end

    it "requires mode to be either 'read' or 'write'" do
      @checker.options['mode'] = 'write'
      expect(@checker).to be_valid
      @checker.options['mode'] = 'write'
      expect(@checker).to be_valid
      @checker.options['mode'] = 'test'
      expect(@checker).not_to be_valid
    end

    it "requires the path to be set" do
      @checker.options['path'] = ''
      expect(@checker).not_to be_valid
    end

    it "requires watch to be present" do
      @checker.options['watch'] = ''
      expect(@checker).not_to be_valid
    end

    it "requires watch to be either 'true' or 'false'" do
      @checker.options['watch'] = 'true'
      expect(@checker).to be_valid
      @checker.options['watch'] = 'false'
      expect(@checker).to be_valid
      @checker.options['watch'] = 'test'
      expect(@checker).not_to be_valid
    end

    it "requires append to be either 'true' or 'false'" do
      @checker.options['append'] = 'true'
      expect(@checker).to be_valid
      @checker.options['append'] = 'false'
      expect(@checker).to be_valid
      @checker.options['append'] = 'test'
      expect(@checker).not_to be_valid
    end
  end

  context "#working" do
    it "is working with no recent errors in read mode" do
      @checker.last_check_at = Time.now
      expect(@checker).to be_working
    end

    it "is working with no recent errors in write mode" do
      @checker.options['mode'] = 'write'
      @checker.last_receive_at = Time.now
      expect(@checker).to be_working
    end
  end

  context "#check_path_existance" do
    it "is truethy when the path exists" do
      expect(@checker.check_path_existance).to be_truthy
    end

    it "is falsy when the path does not exist" do
      @checker.options['path'] = '/doesnotexist'
      expect(@checker.check_path_existance).to be_falsy
    end

    it "create a log entry" do
      @checker.options['path'] = '/doesnotexist'
      expect { @checker.check_path_existance(true) }.to change(AgentLog, :count).by(1)
    end

    it "works with non-expanded paths" do
      @checker.options['path'] = '~'
      expect(@checker.check_path_existance).to be_truthy
    end
  end

  def with_files(*files)
    files.each { |f| FileUtils.touch(f) }
    yield
    files.each { |f| FileUtils.rm(f) }
  end

  context "#check" do
    it "does not create events when the directory is empty" do
      expect { @checker.check }.to change(Event, :count).by(0)
    end

    it "creates an event for every file in the directory" do
      with_files(File.join(Rails.root, 'tmp', 'spec', 'one'), File.join(Rails.root, 'tmp', 'spec', 'two')) do
        expect { @checker.check }.to change(Event, :count).by(2)
        expect(Event.last.payload.has_key?('file_pointer')).to be_truthy
      end
    end

    it "creates an event if the configured file exists" do
      @checker.options['path'] = File.join(Rails.root, 'tmp', 'spec', 'one')
      with_files(File.join(Rails.root, 'tmp', 'spec', 'one'), File.join(Rails.root, 'tmp', 'spec', 'two')) do
        expect { @checker.check }.to change(Event, :count).by(1)
        payload = Event.last.payload
        expect(payload.has_key?('file_pointer')).to be_truthy
        expect(payload['file_pointer']['file']).to eq(@checker.options['path'])
      end
    end

    it "does not run when ENABLE_INSECURE_AGENTS is not set to true" do
      ENV['ENABLE_INSECURE_AGENTS'] = 'false'
      expect { @checker.check }.to change(AgentLog, :count).by(1)
      ENV['ENABLE_INSECURE_AGENTS'] = 'true'
    end
  end

  context "#event_description" do
    it "should include event_type when watch is set to true" do
      @checker.options['watch'] = 'true'
      expect(@checker.event_description).to include('event_type')
    end

    it "should not include event_type when watch is set to false" do
      @checker.options['watch'] = 'false'
      expect(@checker.event_description).not_to include('event_type')
    end
  end

  it "get_io opens the file" do
    mock(File).open('test', 'r')
    @checker.get_io('test')
  end

  context "#start_worker?" do
    it "reeturns true when watch is true" do
      @checker.options['watch'] = 'true'
      expect(@checker.start_worker?).to be_truthy
    end

    it "returns false when watch is false" do
      @checker.options['watch'] = 'false'
      expect(@checker.start_worker?).to be_falsy
    end
  end

  context "#receive" do
    before(:each) do
      @checker.options['mode'] = 'write'
      @checker.options['data'] = '{{ data }}'
      @file_mock = mock()
    end

    it "writes the data at data into a file" do
      mock(@file_mock).write('hello world')
      event = Event.new(payload: {'data' => 'hello world'})
      mock(File).open(File.join(Rails.root, 'tmp', 'spec'), 'w').yields @file_mock
      @checker.receive([event])
    end

    it "appends the data at data onto a file" do
      mock(@file_mock).write('hello world')
      @checker.options['append'] = 'true'
      event = Event.new(payload: {'data' => 'hello world'})
      mock(File).open(File.join(Rails.root, 'tmp', 'spec'), 'a').yields @file_mock
      @checker.receive([event])
    end

    it "does not receive when ENABLE_INSECURE_AGENTS is not set to true" do
      ENV['ENABLE_INSECURE_AGENTS'] = 'false'
      expect { @checker.receive([]) }.to change(AgentLog, :count).by(1)
      ENV['ENABLE_INSECURE_AGENTS'] = 'true'
    end
  end

  describe describe Agents::LocalFileAgent::Worker do
    require 'listen'

    before(:each) do
      @checker.options['watch'] = true
      @checker.save
      @worker = Agents::LocalFileAgent::Worker.new(agent: @checker)
      @listen_mock = mock()
    end

    context "#setup" do
      it "initializes the listen gem" do
        mock(Listen).to(@checker.options['path'], ignore!: [])
        @worker.setup
      end
    end

    context "#run" do
      before(:each) do
        stub(Listen).to { @listen_mock }
        @worker.setup
      end

      it "starts to listen to changes in the directory when the path is present" do
        mock(@worker).sleep
        mock(@listen_mock).start
        @worker.run
      end

      it "does nothing when the path does not exist" do
        mock(@worker.agent).check_path_existance(true) { false }
        dont_allow(@listen_mock).start
        mock(@worker).sleep { raise "Sleeping" }
        expect { @worker.run }.to raise_exception(RuntimeError, 'Sleeping')
      end
    end

    context "#stop" do
      it "stops the listen gem" do
        stub(Listen).to { @listen_mock }
        @worker.setup
        mock(@listen_mock).stop
        @worker.stop
      end
    end

    context "#callback" do
      let(:file) { File.join(Rails.root, 'tmp', 'one') }
      let(:file2) { File.join(Rails.root, 'tmp', 'one2') }

      it "creates an event for modifies files" do
        expect { @worker.send(:callback, [file], [], [])}.to change(Event, :count).by(1)
        payload = Event.last.payload
        expect(payload['event_type']).to eq('modified')
      end

      it "creates an event for modifies files" do
        expect { @worker.send(:callback, [], [file], [])}.to change(Event, :count).by(1)
        payload = Event.last.payload
        expect(payload['event_type']).to eq('added')
      end

      it "creates an event for modifies files" do
        expect { @worker.send(:callback, [], [], [file])}.to change(Event, :count).by(1)
        payload = Event.last.payload
        expect(payload['event_type']).to eq('removed')
      end

      it "creates an event each changed file" do
        expect { @worker.send(:callback, [], [file], [file2])}.to change(Event, :count).by(2)
      end
    end

    context "#listen_options" do
      it "returns the path when a directory is given" do
        expect(@worker.send(:listen_options)).to eq([File.join(Rails.root, 'tmp', 'spec'), ignore!: []])
      end

      it "restricts to only the specified filename" do
        @worker.agent.options['path'] = File.join(Rails.root, 'tmp', 'one')
        expect(@worker.send(:listen_options)).to eq([File.join(Rails.root, 'tmp'), { only: /\Aone\z/, ignore!: [] } ])
      end
    end
  end
end
