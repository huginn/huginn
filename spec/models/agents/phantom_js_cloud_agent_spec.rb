require 'rails_helper'

describe Agents::PhantomJsCloudAgent do
  before do

    @valid_options = {
        'name' => "XKCD",
        'render_type' => "html",
        'url' => "http://xkcd.com",
        'mode' => 'clean',
        'api_key' => '1234567890'
      }

    @checker = Agents::PhantomJsCloudAgent.new(:name => "xkcd", :options => @valid_options, :keep_events_for => 2.days)
    @checker.user = users(:jane)
    @checker.save!
  end

  describe "validations" do
    before do
      expect(@checker).to be_valid
    end

    it "should validate the presence of url" do
      @checker.options['url'] = "http://google.com"
      expect(@checker).to be_valid

      @checker.options['url'] = ""
      expect(@checker).not_to be_valid

      @checker.options['url'] = nil
      expect(@checker).not_to be_valid
    end

  end

  describe "emitting event" do
    it "should emit url as event" do
      expect {
        @checker.check
      }.to change { @checker.events.count }.by(1)

      item,* = @checker.events.last(1)
      expect(item.payload['url']).to eq("https://phantomjscloud.com/api/browser/v2/1234567890/?request=%7B%22url%22%3A%22http%3A%2F%2Fxkcd.com%22%2C%22renderType%22%3A%22html%22%2C%22requestSettings%22%3A%7B%22userAgent%22%3A%22Huginn%20-%20https%3A%2F%2Fgithub.com%2Fhuginn%2Fhuginn%22%7D%7D")
    end

    it "should set render type as plain text" do
      @checker.options['render_type'] = 'plainText'

      expect {
        @checker.check
      }.to change { @checker.events.count }.by(1)

      item,* = @checker.events.last(1)
      expect(item.payload['url']).to eq("https://phantomjscloud.com/api/browser/v2/1234567890/?request=%7B%22url%22%3A%22http%3A%2F%2Fxkcd.com%22%2C%22renderType%22%3A%22plainText%22%2C%22requestSettings%22%3A%7B%22userAgent%22%3A%22Huginn%20-%20https%3A%2F%2Fgithub.com%2Fhuginn%2Fhuginn%22%7D%7D")
    end

    it "should set render type as jpg" do
      @checker.options['render_type'] = 'jpg'

      expect {
        @checker.check
      }.to change { @checker.events.count }.by(1)

      item,* = @checker.events.last(1)
      expect(item.payload['url']).to eq("https://phantomjscloud.com/api/browser/v2/1234567890/?request=%7B%22url%22%3A%22http%3A%2F%2Fxkcd.com%22%2C%22renderType%22%3A%22jpg%22%2C%22requestSettings%22%3A%7B%22userAgent%22%3A%22Huginn%20-%20https%3A%2F%2Fgithub.com%2Fhuginn%2Fhuginn%22%7D%7D")
    end

    it "should set output as json" do
      @checker.options['output_as_json'] = true

      expect {
        @checker.check
      }.to change { @checker.events.count }.by(1)

      item,* = @checker.events.last(1)
      expect(item.payload['url']).to eq("https://phantomjscloud.com/api/browser/v2/1234567890/?request=%7B%22url%22%3A%22http%3A%2F%2Fxkcd.com%22%2C%22renderType%22%3A%22html%22%2C%22outputAsJson%22%3Atrue%2C%22requestSettings%22%3A%7B%22userAgent%22%3A%22Huginn%20-%20https%3A%2F%2Fgithub.com%2Fhuginn%2Fhuginn%22%7D%7D")
    end

    it "should not set ignore images" do
      @checker.options['ignore_images'] = false

      expect {
        @checker.check
      }.to change { @checker.events.count }.by(1)

      item,* = @checker.events.last(1)
      expect(item.payload['url']).to eq("https://phantomjscloud.com/api/browser/v2/1234567890/?request=%7B%22url%22%3A%22http%3A%2F%2Fxkcd.com%22%2C%22renderType%22%3A%22html%22%2C%22requestSettings%22%3A%7B%22userAgent%22%3A%22Huginn%20-%20https%3A%2F%2Fgithub.com%2Fhuginn%2Fhuginn%22%7D%7D")
    end

    it "should set ignore images" do
      @checker.options['ignore_images'] = true

      expect {
        @checker.check
      }.to change { @checker.events.count }.by(1)

      item,* = @checker.events.last(1)
      expect(item.payload['url']).to eq("https://phantomjscloud.com/api/browser/v2/1234567890/?request=%7B%22url%22%3A%22http%3A%2F%2Fxkcd.com%22%2C%22renderType%22%3A%22html%22%2C%22requestSettings%22%3A%7B%22ignoreImages%22%3Atrue%2C%22userAgent%22%3A%22Huginn%20-%20https%3A%2F%2Fgithub.com%2Fhuginn%2Fhuginn%22%7D%7D")
    end

    it "should set wait interval to zero" do
      @checker.options['wait_interval'] = '0'

      expect {
        @checker.check
      }.to change { @checker.events.count }.by(1)

      item,* = @checker.events.last(1)
      expect(item.payload['url']).to eq("https://phantomjscloud.com/api/browser/v2/1234567890/?request=%7B%22url%22%3A%22http%3A%2F%2Fxkcd.com%22%2C%22renderType%22%3A%22html%22%2C%22requestSettings%22%3A%7B%22userAgent%22%3A%22Huginn%20-%20https%3A%2F%2Fgithub.com%2Fhuginn%2Fhuginn%22%2C%22wait_interval%22%3A%220%22%7D%7D")
    end

    it "should set user agent to BlackBerry" do
      @checker.options['user_agent'] = 'Mozilla/5.0 (BlackBerry; U; BlackBerry 9900; en) AppleWebKit/534.11+ (KHTML, like Gecko) Version/7.1.0.346 Mobile Safari/534.11+'

      expect {
        @checker.check
      }.to change { @checker.events.count }.by(1)

      item,* = @checker.events.last(1)
      expect(item.payload['url']).to eq("https://phantomjscloud.com/api/browser/v2/1234567890/?request=%7B%22url%22%3A%22http%3A%2F%2Fxkcd.com%22%2C%22renderType%22%3A%22html%22%2C%22requestSettings%22%3A%7B%22userAgent%22%3A%22Mozilla%2F5.0%20%28BlackBerry%3B%20U%3B%20BlackBerry%209900%3B%20en%29%20AppleWebKit%2F534.11%2B%20%28KHTML%2C%20like%20Gecko%29%20Version%2F7.1.0.346%20Mobile%20Safari%2F534.11%2B%22%7D%7D")
    end



  end

end
