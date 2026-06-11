require 'rails_helper'

shared_examples_for 'FileHandlingConsumer' do
  let(:event) { Event.new(user: @checker.user, payload: {'file_pointer' => {'file' => 'text.txt', 'agent_id' => @checker.id}}) }

  it 'returns a file pointer' do
    file_pointer = @checker.get_file_pointer('testfile')[:file_pointer]

    expect(file_pointer).to include(file: "testfile", agent_id: @checker.id)
    expect(file_pointer[:signature]).to be_present
  end

  it 'get_io raises an exception when trying to access an agent of a different user' do
    @checker2 = @checker.dup
    @checker2.user = users(:bob)
    @checker2.save!
    event.payload['file_pointer']['agent_id'] = @checker2.id
    expect { @checker.get_io(event) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  context '#has_file_pointer?' do
    it 'returns true if the event contains a file pointer' do
      expect(@checker.has_file_pointer?(event)).to be_truthy
    end

    it 'returns false if the event does not contain a file pointer' do
      expect(@checker.has_file_pointer?(Event.new)).to be_falsy
    end
  end

  it '#get_upload_io returns a Faraday::UploadIO instance' do
    expect(@checker).to receive(:get_io).with(event) { StringIO.new("testdata") }

    upload_io = @checker.get_upload_io(event)
    expect(upload_io).to be_a(Faraday::UploadIO)
    expect(upload_io.content_type).to eq('text/plain')
  end
end
