require 'rails_helper'

describe Agents::ReadFileAgent do
  before(:each) do
    @valid_params = {
                      'data_key' => 'data',
                    }

    @checker = Agents::ReadFileAgent.new(:name => 'somename', :options => @valid_params)
    @checker.user = users(:jane)
    @checker.save!
  end

  it_behaves_like 'FileHandlingConsumer'

  context '#validate_options' do
    it 'is valid with the given options' do
      expect(@checker).to be_valid
    end

    it "requires data_key to be present" do
      @checker.options['data_key'] = ''
      expect(@checker).not_to be_valid
    end

    it "requires require_signed_file_pointer to be a boolean value when provided" do
      @checker.options['require_signed_file_pointer'] = 'sometimes'
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
    it "emits an event with the contents of the receives files" do
      event = Event.new(payload: {file_pointer: {agent_id: 111, file: 'test'}})
      expect(@checker).to receive(:get_io).with(event) { StringIO.new("testdata") }
      expect { @checker.receive([event]) }.to change(Event, :count).by(1)
      expect(Event.last.payload).to eq('data' => 'testdata')
    end

    context "with file pointer signature verification" do
      let(:file_path) { Rails.root.join('tmp', 'spec', 'signed-file-pointer.txt').to_s }
      let(:other_file_path) { Rails.root.join('tmp', 'spec', 'forged-file-pointer.txt').to_s }

      before do
        FileUtils.mkdir_p File.dirname(file_path)
        File.write(file_path, "signed data")
        File.write(other_file_path, "forged data")
        @file_agent = Agents::LocalFileAgent.create!(
          name: "file source",
          user: @checker.user,
          options: {
            'mode' => 'read',
            'watch' => 'false',
            'append' => 'false',
            'path' => file_path
          }
        )
      end

      after do
        FileUtils.rm_f(file_path)
        FileUtils.rm_f(other_file_path)
      end

      it "reads a file pointer emitted by a file-handling agent" do
        @checker.options['require_signed_file_pointer'] = true
        event = Event.new(user: @checker.user, payload: signed_payload(file_path))

        expect { @checker.receive([event]) }.to change(Event, :count).by(1)
        expect(Event.last.payload).to eq('data' => 'signed data')
      end

      it "ignores an unsigned file pointer when verification is enabled" do
        @checker.options['require_signed_file_pointer'] = true
        event = Event.new(user: @checker.user, payload: forged_payload(file_path))

        expect { @checker.receive([event]) }.not_to change(Event, :count)
      end

      it "ignores a tampered file pointer when verification is enabled" do
        @checker.options['require_signed_file_pointer'] = true
        payload = signed_payload(file_path)
        payload['file_pointer']['file'] = other_file_path
        event = Event.new(user: @checker.user, payload: payload)

        expect { @checker.receive([event]) }.not_to change(Event, :count)
      end

      it "keeps accepting unsigned file pointers when verification is not configured" do
        event = Event.new(user: @checker.user, payload: forged_payload(file_path))

        expect { @checker.receive([event]) }.to change(Event, :count).by(1)
        expect(Event.last.payload).to eq('data' => 'signed data')
      end

      def signed_payload(file)
        JSON.parse(@file_agent.get_file_pointer(file).to_json)
      end

      def forged_payload(file)
        {
          'file_pointer' => {
            'agent_id' => @file_agent.id,
            'file' => file
          }
        }
      end
    end
  end
end
