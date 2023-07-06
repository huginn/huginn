require 'rails_helper'

describe Agents::S3Agent do
  before(:each) do
    @valid_params = {
                      'mode' => 'read',
                      'access_key_id' => '32343242',
                      'access_key_secret' => '1231312',
                      'watch' => 'false',
                      'bucket' => 'testbucket',
                      'region' => 'us-east-1',
                      'filename' => 'test.txt',
                      'data' => '{{ data }}'
                    }

    @checker = Agents::S3Agent.new(:name => "somename", :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!
  end

  describe "#validate_options" do
    it "requires the bucket to be set" do
      @checker.options['bucket'] = ''
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

    it "requires region to be present" do
      @checker.options['region'] = ''
      expect(@checker).not_to be_valid
    end

    it "requires mode to be set to 'read' or 'write'" do
      @checker.options['mode'] = 'write'
      expect(@checker).to be_valid
      @checker.options['mode'] = ''
      expect(@checker).not_to be_valid
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

  describe "#validating" do
    it "validates the key" do
      expect(@checker).to receive(:client) {
        Aws::S3::Client.new(stub_responses: { list_buckets: ['SignatureDoesNotMatch'] })
      }
      expect(@checker.validate_access_key_id).to be_falsy
    end

    it "validates the secret" do
      expect(@checker).to receive(:buckets) { true }
      expect(@checker.validate_access_key_secret).to be_truthy
    end
  end

  it "completes the buckets" do
    expect(@checker).to receive(:buckets) { [OpenStruct.new(name: 'test'), OpenStruct.new(name: 'test2')]}
    expect(@checker.complete_bucket).to eq([{text: 'test', id: 'test'}, {text: 'test2', id: 'test2'}])
  end

  context "#working" do
    it "is working with no recent errors" do
      @checker.last_check_at = Time.now
      expect(@checker).to be_working
    end
  end

  context "#check" do
    context "not watching" do
      it "emits an event for every file" do
        expect(@checker).to receive(:get_bucket_contents) { {"test"=>"231232", "test2"=>"4564545"} }
        expect { @checker.check }.to change(Event, :count).by(2)
        expect(Event.last.payload).to eq({"file_pointer" => {"file"=>"test2", "agent_id"=> @checker.id}})
      end
    end

    context "watching" do
      before(:each) do
        @checker.options['watch'] = 'true'
      end

      it "does not emit any events on the first run" do
        contents = {"test"=>"231232", "test2"=>"4564545"}
        expect(@checker).to receive(:get_bucket_contents) { contents }
        expect { @checker.check }.not_to change(Event, :count)
        expect(@checker.memory).to eq('seen_contents' => contents)
      end

      context "detecting changes" do
        before(:each) do
          contents = {"test"=>"231232", "test2"=>"4564545"}
          expect(@checker).to receive(:get_bucket_contents) { contents }
          expect { @checker.check }.not_to change(Event, :count)
          @checker.last_check_at = Time.now
        end

        it "emits events for removed files" do
          contents = {"test"=>"231232"}
          expect(@checker).to receive(:get_bucket_contents) { contents }
          expect { @checker.check }.to change(Event, :count).by(1)
          expect(Event.last.payload).to eq({"file_pointer" => {"file" => "test2", "agent_id"=> @checker.id}, "event_type" => "removed"})
        end

        it "emits events for modified files" do
          contents = {"test"=>"231232", "test2"=>"changed"}
          expect(@checker).to receive(:get_bucket_contents) { contents }
          expect { @checker.check }.to change(Event, :count).by(1)
          expect(Event.last.payload).to eq({"file_pointer" => {"file" => "test2", "agent_id"=> @checker.id}, "event_type" => "modified"})
        end
        it "emits events for added files" do
          contents = {"test"=>"231232", "test2"=>"4564545", "test3" => "31231231"}
          expect(@checker).to receive(:get_bucket_contents) { contents }
          expect { @checker.check }.to change(Event, :count).by(1)
          expect(Event.last.payload).to eq({"file_pointer" => {"file" => "test3", "agent_id"=> @checker.id}, "event_type" => "added"})
        end
      end

      context "error handling" do
        it "handles AccessDenied exceptions" do
          expect(@checker).to receive(:client) {
            Aws::S3::Client.new(stub_responses: { list_objects: ['AccessDenied'] })
          }
          expect { @checker.check }.to change(AgentLog, :count).by(1)
          expect(AgentLog.last.message).to match(/Could not access 'testbucket' Aws::S3::Errors::AccessDenied/)
        end

        it "handles generic S3 exceptions" do
          expect(@checker).to receive(:client) {
            Aws::S3::Client.new(stub_responses: { list_objects: ['PermanentRedirect'] })
          }
          expect { @checker.check }.to change(AgentLog, :count).by(1)
          expect(AgentLog.last.message).to eq("Aws::S3::Errors::PermanentRedirect: stubbed-response-error-message")
        end
      end
    end
  end

  it "get_io returns a StringIO object" do
    stringio =StringIO.new
    mock_response = double()
    expect(mock_response).to receive(:body) { stringio }
    mock_client = double()
    expect(mock_client).to receive(:get_object).with(bucket: 'testbucket', key: 'testfile') { mock_response }
    expect(@checker).to receive(:client) { mock_client }
    @checker.get_io('testfile')
  end

  context "#get_bucket_contents" do
    it "returns a hash with the contents of the bucket" do
      mock_response = double()
      expect(mock_response).to receive(:contents) { [OpenStruct.new(key: 'test', etag: '231232'), OpenStruct.new(key: 'test2', etag: '4564545')] }
      mock_client = double()
      expect(mock_client).to receive(:list_objects).with(bucket: 'testbucket') { [mock_response] }
      expect(@checker).to receive(:client) { mock_client }
      expect(@checker.send(:get_bucket_contents)).to eq({"test"=>"231232", "test2"=>"4564545"})
    end
  end

  context "#client" do
    it "initializes the S3 client correctly" do
      mock_credential = double()
      expect(Aws::Credentials).to receive(:new).with('32343242', '1231312') { mock_credential }
      expect(Aws::S3::Client).to receive(:new).with(credentials: mock_credential,
                                      region: 'us-east-1')
      @checker.send(:client)
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

  context "#receive" do
    before(:each) do
      @checker.options['mode'] = 'write'
      @checker.options['filename'] = 'file.txt'
      @checker.options['data'] = '{{ data }}'
    end

    it "writes the data at data into a file" do
      client_mock = double()
      expect(client_mock).to receive(:put_object).with(bucket: @checker.options['bucket'], key: @checker.options['filename'], body: 'hello world!')
      expect(@checker).to receive(:client) { client_mock }
      event = Event.new(payload: {'data' => 'hello world!'})
      @checker.receive([event])
    end

    it "does nothing when mode is set to 'read'" do
      @checker.options['mode'] = 'read'
      event = Event.new(payload: {'data' => 'hello world!'})
      @checker.receive([event])
    end
  end
end
