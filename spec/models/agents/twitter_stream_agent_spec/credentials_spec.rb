require 'spec_helper'

describe Agents::TwitterStreamAgent do
  describe "#valid_credentials" do 
    let(:stream) { Agents::TwitterStreamAgent.new }
    let(:invalid_error_message) { "Twitter credentials are invalid, a connection could not be established" }
    let(:user) { User.new }
    before do 
      stream.user = user
    end
    context "invalid credentials" do 
      it 'includes invalid credential errors' do 
        mock.any_instance_of(Twitter::REST::Client).verify_credentials { raise Twitter::Error::Unauthorized.new("invalid") }
        stream.valid?
        expect(stream.errors.full_messages).to include(invalid_error_message)
      end
    end

    context "valid credentials" do 
      it 'includes invalid credential errors' do 
        mock.any_instance_of(Twitter::REST::Client).verify_credentials { true }
        stream.valid?
        expect(stream.errors.full_messages).to_not include(invalid_error_message)
      end
    end
  end
end