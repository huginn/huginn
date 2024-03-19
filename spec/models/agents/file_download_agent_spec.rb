require 'rails_helper'

describe Agents::FileDownloadAgent do
  describe "validate" do
    # TODO
  end

  describe "#receive" do
    describe "should receive and" do
      before do
        @opts = {
          :url => "{{ url }}",
          :expected_update_period_in_days => 10,
          :mode => "{{ mode }}",
          :destination => "/tmp/video.mp4"
        }

        instance_of(Agents::FileDownloadAgent) do
          save("/tmp/video.mp4", "response from get") {
            "/tmp/video.mp4"
          }
        end
        instance_of(Agents::FileDownloadAgent) do
          download("http://example.org/video.mp4?secret=pssst") {
            resp = OpenStruct.new
            resp.body = "response from get"
            resp
          }
        end
        @checker = Agents::FileDownloadAgent.new(
          :name => "TestFileDownloader",
          :options => @opts
        )
        @checker.service = services(:generic)
        @checker.user = users(:bob)
        @checker.save!
      end

      it "should download the file and save it" do
        event = Event.new
        event.agent = agents(:bob_weather_agent)
        event.payload = {
          :url => "http://example.org/video.mp4?secret=pssst",
          :mode => "clean"
        }
        event.save!
        Agents::FileDownloadAgent.async_receive(@checker.id, [event.id])
        expect(@checker.events.count).to eq(1)
        expect(@checker.events.first.payload).to eq({
          "destination" => "/tmp/video.mp4"
        })
      end

      it "should download the file and save it using merge" do
        event = Event.new
        event.agent = agents(:bob_weather_agent)
        event.payload = {
          :url => "http://example.org/video.mp4?secret=pssst",
          :my_special_prop => "my_special_value",
          :mode => "merge"
        }
        event.save!
        Agents::FileDownloadAgent.async_receive(@checker.id, [event.id])
        expect(@checker.events.count).to eq(1)
        expect(@checker.events.first.payload["destination"]).to start_with("/tmp/video.mp4")
        expect(@checker.events.first.payload["my_special_prop"]).to eq("my_special_value")
      end
    end

    describe "should handle error" do
      before do
        @opts = {
          :url => "{{url}}",
          :expected_update_period_in_days => 10,
        }

        @checker = Agents::FileDownloadAgent.new(
          :name => "TestFileDownloader",
          :options => @opts
        )
        @checker.service = services(:generic)
        @checker.user = users(:bob)
        @checker.save!

        @event = Event.new
        @event.agent = agents(:bob_weather_agent)
        @event.payload = {
          :url => "http://example.org/video.mp4?secret=pssst",
          :destination => "/tmp/video.mp4",
        }
        @event.save!

        instance_of(Agents::FileDownloadAgent) do
          download("http://example.org/video.mp4?secret=pssst") {
            raise "Dummy error"
          }

          log("Failed to download http://example.org/video.mp4?secret=pssst to <tmp>: Dummy error")
        end
      end

      it "should download the file and save it" do
        Agents::FileDownloadAgent.async_receive(@checker.id, [@event.id])
        expect(@checker.events.count).to eq(0)
      end
    end

  end

  describe "#save" do
    describe "no destination" do
      before do
        instance_of(Tempfile) do
          new(anything, {:encoding => 'ascii-8bit'}) {

          }
          path {
            '/tmp/file'
          }
          write("content") {
            true
          }
          close {

          }
        end
        @opts = {
          :url => "{{ url }}",
          :expected_update_period_in_days => 10,
          :mode => "{{ mode }}",
          :destination => "/tmp/video.mp4"
        }

        @checker = Agents::FileDownloadAgent.new(
          :name => "TestFileDownloader",
          :options => @opts
        )
      end
      it "should create tmpfile, write and return the path" do
        expect(@checker.save(nil, "content")).to eq('/tmp/file')
      end
    end

    describe "has destination" do
      before do
        stub(File).open("/tmp/video.mp4", "wb") {
          obj = Object.new
          stub(obj).write("content") { true }
          stub(obj).close() { true }
          stub(obj).path { "/tmp/video.mp4" }
          obj
        }
        @opts = {
          :url => "{{ url }}",
          :expected_update_period_in_days => 10,
          :mode => "{{ mode }}",
          :destination => "/tmp/video.mp4"
        }

        @checker = Agents::FileDownloadAgent.new(
          :name => "TestFileDownloader",
          :options => @opts
        )
      end
      it "should save there and return the path" do
        expect(@checker.save("/tmp/video.mp4", "content")).to eq('/tmp/video.mp4')
      end
    end

    describe "when io throws" do
      before(:each) do
        instance_of(Tempfile) do
          new(anything, {:encoding => 'ascii-8bit'}) {

          }
          path {
            "/tmp/file"
          }
          write("content") {
            raise "dummy error"
          }
          close {
          }
        end

        @opts = {
          :url => "{{ url }}",
          :expected_update_period_in_days => 10,
          :mode => "{{ mode }}",
          :destination => "/tmp/video.mp4"
        }

        @checker = Agents::FileDownloadAgent.new(
          :name => "TestFileDownloader",
          :options => @opts
        )
      end
      it "should close the handle and rethrow" do
        expect{@checker.save(nil, "content")}.to raise_error /dummy/
      end
    end

  end

  describe "#download" do
    before do
      @opts = {
        :url => "{{ url }}",
        :expected_update_period_in_days => 10,
        :mode => "{{ mode }}",
        :destination => "/tmp/video.mp4"
      }

      @checker = Agents::FileDownloadAgent.new(
        :name => "TestFileDownloader",
        :options => @opts
      )

      @url = "http://example.org/video.mp4?secret=psst"
      stub.proxy(Faraday).new("http://example.org") { |obj|
        stub(obj).get("/video.mp4?secret=psst") {
          resp =  OpenStruct.new
          resp.body = "response from get"
          resp
        }
        obj
      }
    end
    it "should download the file and return the value" do
      response = @checker.download(@url)
      expect(response.body).to eq("response from get")
    end
  end
end
