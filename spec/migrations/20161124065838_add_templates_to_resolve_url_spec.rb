load 'spec/rails_helper.rb'
load File.join('db/migrate', File.basename(__FILE__, '_spec.rb') + '.rb')

describe AddTemplatesToResolveUrl do
  let :valid_options do
    {
      'name' => "XKCD",
      'expected_update_period_in_days' => "2",
      'type' => "html",
      'url' => "http://xkcd.com",
      'mode' => 'on_change',
      'extract' => {
        'url' => { 'css' => "#comic img", 'value' => "@src" },
        'title' => { 'css' => "#comic img", 'value' => "@alt" },
        'hovertext' => { 'css' => "#comic img", 'value' => "@title" }
      }
    }
  end

  let :agent do
    Agents::WebsiteAgent.create!(
      user: users(:bob),
      name: "xkcd",
      options: valid_options,
      keep_events_for: 2.days
    )
  end

  it 'should add a template for an existing WebsiteAgent with `url`' do
    expect(agent.options).not_to include('template')
    AddTemplatesToResolveUrl.new.up
    agent.reload
    expect(agent.options).to include(
      'template' => {
        'url' => '{{ url | to_uri: _response_.url }}'
      }
    )
  end
end
