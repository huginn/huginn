require 'rails_helper'

describe Agents::CsvAgent do
  before(:each) do
    @valid_params = {
                      'mode' => 'parse',
                      'separator' => ',',
                      'use_fields' => '',
                      'output' => 'event_per_row',
                      'with_header' => 'true',
                      'data_path' => '$.data',
                      'data_key' => 'data'
                    }

    @checker = Agents::CsvAgent.new(:name => 'somename', :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!
    @lfa = Agents::LocalFileAgent.new(name: 'local', options: {path: '{{}}', watch: 'false', append: 'false', mode: 'read'})
    @lfa.user = users(:jane)
    @lfa.save!
  end

  it_behaves_like 'FileHandlingConsumer'

  context '#validate_options' do
    it 'is valid with the given options' do
      expect(@checker).to be_valid
    end

    it "requires with_header to be either 'true' or 'false'" do
      @checker.options['with_header'] = 'true'
      expect(@checker).to be_valid
      @checker.options['with_header'] = 'false'
      expect(@checker).to be_valid
      @checker.options['with_header'] = 'test'
      expect(@checker).not_to be_valid
    end

    it "data_path has to be set in serialize mode" do
      @checker.options['mode'] = 'serialize'
      @checker.options['data_path'] = ''
      expect(@checker).not_to be_valid
    end
  end

  context '#working' do
    it 'is not working without having received an event' do
      expect(@checker).not_to be_working
    end

    it 'is working after receiving an event without error' do
      @checker.last_receive_at = Time.now
      expect(@checker).to be_working
    end
  end

  context '#receive' do
    after(:all) do
      FileUtils.rm(File.join(Rails.root, 'tmp', 'csv'))
    end

    def event_with_contents(contents)
      path = File.join(Rails.root, 'tmp', 'csv')
      File.open(path, 'w') do |f|
        f.write(contents)
      end
      Event.new(payload: { 'file_pointer' => {'agent_id' => @lfa.id, 'file' => path } }, user_id: @checker.user_id)
    end

    context "agent options" do
      let(:with_headers) { event_with_contents("one,two\n1,2\n2,3") }
      let(:without_headers) { event_with_contents("1,2\n2,3") }

      context "output" do
        it "creates one event per row" do
          @checker.options['output'] = 'event_per_row'
          expect { @checker.receive([with_headers]) }.to change(Event, :count).by(2)
          expect(Event.last.payload).to eq(@checker.options['data_key'] => {'one' => '2', 'two' => '3'})
        end

        it "creates one event per file" do
          @checker.options['output'] = 'event_per_file'
          expect { @checker.receive([with_headers]) }.to change(Event, :count).by(1)
          expect(Event.last.payload).to eq(@checker.options['data_key'] => [{"one"=>"1", "two"=>"2"}, {"one"=>"2", "two"=>"3"}])
        end
      end

      context "with_header" do
        it "works without headers" do
          @checker.options['with_header'] = 'false'
          expect { @checker.receive([without_headers]) }.to change(Event, :count).by(2)
          expect(Event.last.payload).to eq({@checker.options['data_key']=>["2", "3"]})
        end

        it "works without headers and event_per_file" do
          @checker.options['with_header'] = 'false'
          @checker.options['output'] = 'event_per_file'
          expect { @checker.receive([without_headers]) }.to change(Event, :count).by(1)
          expect(Event.last.payload).to eq({@checker.options['data_key']=>[['1', '2'], ["2", "3"]]})
        end
      end

      context "use_fields" do
        it "extracts the specified columns" do
          @checker.options['use_fields'] = 'one'
          expect { @checker.receive([with_headers]) }.to change(Event, :count).by(2)
          expect(Event.last.payload).to eq(@checker.options['data_key'] => {'one' => '2'})
        end
      end

      context "data_path" do
        it "can receive the CSV via a regular event" do
          @checker.options['data_path'] = '$.data'
          event = Event.new(payload: {'data' => "one,two\r\n1,2\r\n2,3"})
          expect { @checker.receive([event]) }.to change(Event, :count).by(2)
          expect(Event.last.payload).to eq(@checker.options['data_key'] => {'one' => '2', 'two' => '3'})
        end
      end
    end

    context "handling different CSV formats" do
      it "works with windows line endings" do
        event = event_with_contents("one,two\r\n1,2\r\n2,3")
        expect { @checker.receive([event]) }.to change(Event, :count).by(2)
        expect(Event.last.payload).to eq(@checker.options['data_key'] => {'one' => '2', 'two' => '3'})
      end

      it "works with OSX line endings" do
        event = event_with_contents("one,two\r1,2\r2,3")
        expect { @checker.receive([event]) }.to change(Event, :count).by(2)
        expect(Event.last.payload).to eq(@checker.options['data_key'] => {'one' => '2', 'two' => '3'})
      end

      it "handles quotes correctly" do
        event = event_with_contents("\"one\",\"two\"\n1,2\n\"\"2, two\",3")
        expect { @checker.receive([event]) }.to change(Event, :count).by(2)
        expect(Event.last.payload).to eq(@checker.options['data_key'] => {'one' => '"2, two', 'two' => '3'})
      end

      it "works with tab seperated csv" do
        event = event_with_contents("one\ttwo\r\n1\t2\r\n2\t3")
        @checker.options['separator'] = '\\t'
        expect { @checker.receive([event]) }.to change(Event, :count).by(2)
        expect(Event.last.payload).to eq(@checker.options['data_key'] => {'one' => '2', 'two' => '3'})
      end
    end

    context "serializing" do
      before(:each) do
        @checker.options['mode'] = 'serialize'
        @checker.options['data_path'] = '$.data'
        @checker.options['data_key'] = 'data'
      end

      it "writes headers when with_header is true" do
        event = Event.new(payload: { 'data' => {'key' => 'value', 'key2' => 'value2', 'key3' => 'value3'} })
        expect { @checker.receive([event])}.to change(Event, :count).by(1)
        expect(Event.last.payload).to eq('data' => "\"key\",\"key2\",\"key3\"\n\"value\",\"value2\",\"value3\"\n")
      end

      it "writes one row per received event" do
        event = Event.new(payload: { 'data' => {'key' => 'value', 'key2' => 'value2', 'key3' => 'value3'} })
        event2 = Event.new(payload: { 'data' => {'key' => '2value', 'key2' => '2value2', 'key3' => '2value3'} })
        expect { @checker.receive([event, event2])}.to change(Event, :count).by(1)
        expect(Event.last.payload).to eq('data' => "\"key\",\"key2\",\"key3\"\n\"value\",\"value2\",\"value3\"\n\"2value\",\"2value2\",\"2value3\"\n")
      end

      it "accepts multiple rows per event" do
        event = Event.new(payload: { 'data' => [{'key' => 'value', 'key2' => 'value2', 'key3' => 'value3'}, {'key' => '2value', 'key2' => '2value2', 'key3' => '2value3'}] })
        expect { @checker.receive([event])}.to change(Event, :count).by(1)
        expect(Event.last.payload).to eq('data' => "\"key\",\"key2\",\"key3\"\n\"value\",\"value2\",\"value3\"\n\"2value\",\"2value2\",\"2value3\"\n")
      end

      it "does not write the headers when with_header is false" do
        @checker.options['with_header'] = 'false'
        event = Event.new(payload: { 'data' => {'key' => 'value', 'key2' => 'value2', 'key3' => 'value3'} })
        expect { @checker.receive([event])}.to change(Event, :count).by(1)
        expect(Event.last.payload).to eq('data' => "\"value\",\"value2\",\"value3\"\n")
      end

      it "only serialize the keys specified in use_fields" do
        @checker.options['use_fields'] = 'key2, key3'
        event = Event.new(payload: { 'data' => {'key' => 'value', 'key2' => 'value2', 'key3' => 'value3'} })
        expect { @checker.receive([event])}.to change(Event, :count).by(1)
        expect(Event.last.payload).to eq('data' => "\"key2\",\"key3\"\n\"value2\",\"value3\"\n")
      end

      it "respects the order of use_fields" do
        @checker.options['use_fields'] = 'key3, key'
        event = Event.new(payload: { 'data' => {'key' => 'value', 'key2' => 'value2', 'key3' => 'value3'} })
        expect { @checker.receive([event])}.to change(Event, :count).by(1)
        expect(Event.last.payload).to eq('data' => "\"key3\",\"key\"\n\"value3\",\"value\"\n")
      end

      it "respects use_fields and writes no header" do
        @checker.options['with_header'] = 'false'
        @checker.options['use_fields'] = 'key2, key3'
        event = Event.new(payload: { 'data' => {'key' => 'value', 'key2' => 'value2', 'key3' => 'value3'} })
        expect { @checker.receive([event])}.to change(Event, :count).by(1)
        expect(Event.last.payload).to eq('data' => "\"value2\",\"value3\"\n")
      end

      context "arrays" do
        it "does not write a header" do
          @checker.options['with_header'] = 'false'
          event = Event.new(payload: { 'data' => ['value1', 'value2'] })
          event2 = Event.new(payload: { 'data' => ['value3', 'value4'] })
          expect { @checker.receive([event, event2])}.to change(Event, :count).by(1)
          expect(Event.last.payload).to eq('data' => "\"value1\",\"value2\"\n\"value3\",\"value4\"\n")
        end

        it "handles nested arrays" do
          event = Event.new(payload: { 'data' => [['value1', 'value2'], ['value3', 'value4']] })
          expect { @checker.receive([event])}.to change(Event, :count).by(1)
          expect(Event.last.payload).to eq('data' => "\"value1\",\"value2\"\n\"value3\",\"value4\"\n")
        end
      end
    end
  end

  context '#event_description' do
    it "works with event_per_row and headers" do
      @checker.options['output'] = 'event_per_row'
      @checker.options['with_header'] = 'true'
      description = @checker.event_description
      expect(description).not_to match(/\n\s+\[\n/)
      expect(description).to include(": {\n")
    end

    it "works with event_per_file and without headers" do
      @checker.options['output'] = 'event_per_file'
      @checker.options['with_header'] = 'false'
      description = @checker.event_description
      expect(description).to match(/\n\s+\[\n/)
      expect(description).not_to include(": {\n")
    end

    it "shows dummy CSV when in serialize mode" do
      @checker.options['mode'] = 'serialize'
      description = @checker.event_description
      expect(description).to include('"generated\",\"csv')
    end
  end
end
