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
      io_mock = mock()
      mock(@checker).get_io(event) { StringIO.new("testdata") }
      expect { @checker.receive([event]) }.to change(Event, :count).by(1)
      expect(Event.last.payload).to eq('data' => 'testdata')
    end
  end
end
