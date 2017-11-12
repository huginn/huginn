require 'rails_helper'

describe "Dry running an Agent", js: true do
  let(:agent)   { agents(:bob_website_agent) }
  let(:formatting_agent) { agents(:bob_formatting_agent) }
  let(:user)    { users(:bob) }
  let(:emitter) { agents(:bob_weather_agent) }

  before(:each) do
    login_as(user)
  end

  def open_dry_run_modal(agent)
    visit edit_agent_path(agent)
    click_on("Dry Run")
    expect(page).to have_text('Event to send')
  end

  context 'successful dry runs' do
    before do
      stub_request(:get, "http://xkcd.com/").
        with(:headers => {'Accept-Encoding'=>'gzip,deflate', 'User-Agent'=>'Huginn - https://github.com/huginn/huginn'}).
        to_return(:status => 200, :body => File.read(Rails.root.join("spec/data_fixtures/xkcd.html")), :headers => {})
    end

    it 'opens the dry run modal even when clicking on the refresh icon' do
      visit edit_agent_path(agent)
      find('.agent-dry-run-button span.glyphicon').click
      expect(page).to have_text('Event to send (Optional)')
    end

    it 'shows the dry run pop up without previous events and selects the events tab when a event was created' do
      open_dry_run_modal(agent)
      click_on("Dry Run")
      expect(page).to have_text('Biologists play reverse')
      expect(page).to have_selector(:css, 'li[role="presentation"].active a[href="#tabEvents"]')
    end

    it 'shows the dry run pop up with previous events and allows use previously received event' do
      emitter.events << Event.new(payload: {url: "http://xkcd.com/"})
      agent.sources << emitter
      agent.options.merge!('url' => '', 'url_from_event' => '{{url}}')
      agent.save!

      open_dry_run_modal(agent)
      find('.dry-run-event-sample').click
      within(:css, '.modal .builder') do
        expect(page).to have_text('http://xkcd.com/')
      end
      click_on("Dry Run")
      expect(page).to have_text('Biologists play reverse')
      expect(page).to have_selector(:css, 'li[role="presentation"].active a[href="#tabEvents"]')
    end

    it 'sends escape characters correctly to the backend' do
      emitter.events << Event.new(payload: {data: "Line 1\nLine 2\nLine 3"})
      formatting_agent.sources << emitter
      formatting_agent.options.merge!('instructions' => {'data' => "{{data | newline_to_br | strip_newlines | split: '<br />' | join: ','}}"})
      formatting_agent.save!

      open_dry_run_modal(formatting_agent)
      find('.dry-run-event-sample').click
      within(:css, '.modal .builder') do
        expect(page).to have_text('Line 1\nLine 2\nLine 3')
      end
      click_on("Dry Run")
      expect(page).to have_text('Line 1,Line 2,Line 3')
      expect(page).to have_selector(:css, 'li[role="presentation"].active a[href="#tabEvents"]')
    end
  end

  it 'shows the dry run pop up without previous events and selects the log tab when no event was created' do
    stub_request(:get, "http://xkcd.com/").
      with(:headers => {'Accept-Encoding'=>'gzip,deflate', 'User-Agent'=>'Huginn - https://github.com/huginn/huginn'}).
      to_return(:status => 200, :body => "", :headers => {})

    open_dry_run_modal(agent)
    click_on("Dry Run")
    expect(page).to have_text('Dry Run started')
    expect(page).to have_selector(:css, 'li[role="presentation"].active a[href="#tabLog"]')
  end
end
