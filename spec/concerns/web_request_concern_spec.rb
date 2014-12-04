require 'spec_helper'

describe WebRequestConcern do
  before do
    class WebRequestConcernTest < Agent
      include WebRequestConcern
    end
  end

  describe '#faraday' do
    it 'should set up the User-Agent headers' do
      web_request = WebRequestConcernTest.new()
      faraday = web_request.faraday
      expect(faraday.headers['User-Agent']).to eq(web_request.user_agent)
    end

    it 'should follow redirects' do
      web_request = WebRequestConcernTest.new()
      faraday = web_request.faraday
      expect(faraday.builder.handlers).to include(FaradayMiddleware::FollowRedirects)
    end

    it 'should enable SSL verification by default' do
      web_request = WebRequestConcernTest.new()
      faraday = web_request.faraday
      expect(faraday.ssl.verify).to eq(true)
    end

    it 'should disable SSL verification if disable_ssl_verification option is true' do
      web_request = WebRequestConcernTest.new(options: { disable_ssl_verification: true })
      faraday = web_request.faraday
      expect(faraday.ssl.verify).to eq(false)
    end
  end

  describe '#validate_web_request_options!' do
    it 'should be valid with only default options' do
      web_request = WebRequestConcernTest.new()
      web_request.validate_web_request_options!
      expect(web_request.errors[:base]).to be_empty
    end

    describe 'user_agent' do
      it 'should be a string' do
        web_request = WebRequestConcernTest.new(options: { user_agent: 'Huginn' } )
        web_request.validate_web_request_options!
        expect(web_request.errors[:base]).to be_empty
      end

      it 'should be invalid if not a string' do
        web_request = WebRequestConcernTest.new(options: { user_agent: 42 } )
        web_request.validate_web_request_options!
        expect(web_request.errors[:base]).to_not be_empty
      end
    end

    describe 'headers' do
      it 'should be a hash' do
        web_request = WebRequestConcernTest.new(options: { headers: {} } )
        web_request.validate_web_request_options!
        expect(web_request.errors[:base]).to be_empty
      end

      it 'should be invalid if not a hash' do
        web_request = WebRequestConcernTest.new(options: { headers: 42 } )
        web_request.validate_web_request_options!
        expect(web_request.errors[:base]).to_not be_empty
      end
    end

    describe 'basic_auth' do
      it 'should be valid if basic_auth_credentials doesnt raise error' do
        web_request = WebRequestConcernTest.new()
        expect { web_request.basic_auth_credentials }.to_not raise_error
        web_request.validate_web_request_options!
        expect(web_request.errors[:base]).to be_empty
      end

      it 'should be invalid if basic_auth_credentials raises error' do
        web_request = WebRequestConcernTest.new(options: { basic_auth: 'invalid' })
        expect { web_request.basic_auth_credentials }.to raise_error(ArgumentError)
        web_request.validate_web_request_options!
        expect(web_request.errors[:base]).to_not be_empty
      end
    end

    describe 'disable_ssl_verification' do
      it 'should be a boolean' do
        web_request = WebRequestConcernTest.new(options: { disable_ssl_verification: true } )
        web_request.validate_web_request_options!
        expect(web_request.errors[:base]).to be_empty
      end

      it 'should be invalid if not a boolean' do
        web_request = WebRequestConcernTest.new(options: { disable_ssl_verification: 42 } )
        web_request.validate_web_request_options!
        expect(web_request.errors[:base]).to_not be_empty
      end
    end
  end
end
