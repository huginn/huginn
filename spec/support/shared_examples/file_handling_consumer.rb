require 'rails_helper'

shared_examples_for 'FileHandlingConsumer' do
  it 'returns a file pointer' do
    expect(@checker.get_file_pointer('testfile')).to eq(file_pointer: { file: "testfile", agent_id: @checker.id})
  end

  it 'get_io raises an exception when trying to access an agent of a different user' do
    @checker2 = @checker.dup
    @checker2.user = users(:bob)
    @checker2.save!
    expect(@checker2.user.id).not_to eq(@checker.user.id)
    event = Event.new(user: @checker.user, payload: {'file_pointer' => {'file' => 'test', 'agent_id' => @checker2.id}})
    expect { @checker.get_io(event) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end