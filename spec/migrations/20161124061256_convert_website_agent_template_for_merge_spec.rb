load 'spec/rails_helper.rb'
load File.join('db/migrate', File.basename(__FILE__, '_spec.rb') + '.rb')

describe ConvertWebsiteAgentTemplateForMerge do
  let :old_extract do
    {
      'url' => { 'css' => "#comic img", 'value' => "@src" },
      'title' => { 'css' => "#comic img", 'value' => "@alt" },
      'hovertext' => { 'css' => "#comic img", 'value' => "@title" }
    }
  end

  let :new_extract do
    {
      'url' => { 'css' => "#comic img", 'value' => "@src" },
      'title' => { 'css' => "#comic img", 'value' => "@alt" },
      'hovertext' => { 'css' => "#comic img", 'value' => "@title", 'hidden' => true }
    }
  end

  let :reverted_extract do
    old_extract
  end

  let :old_template do
    {
      'url' => '{{url}}',
      'title' => '{{ title }}',
      'description' => '{{ hovertext }}',
      'comment' => '{{ comment }}'
    }
  end

  let :new_template do
    {
      'description' => '{{ hovertext }}',
      'comment' => '{{ comment }}'
    }
  end

  let :reverted_template do
    old_template.merge('url' => '{{ url }}')
  end

  let :valid_options do
    {
      'name' => "XKCD",
      'expected_update_period_in_days' => "2",
      'type' => "html",
      'url' => "{{ url | default: 'http://xkcd.com/' }}",
      'mode' => 'on_change',
      'extract' => old_extract,
      'template' => old_template
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

  describe 'up' do
    it 'should update extract and template options for an existing WebsiteAgent' do
      expect(agent.options).to include('extract' => old_extract,
                                       'template' => old_template)
      ConvertWebsiteAgentTemplateForMerge.new.up
      agent.reload
      expect(agent.options).to include('extract' => new_extract,
                                       'template' => new_template)
    end
  end

  describe 'down' do
    let :valid_options do
      super().merge('extract' => new_extract,
                    'template' => new_template)
    end

    it 'should revert extract and template options for an updated WebsiteAgent' do
      expect(agent.options).to include('extract' => new_extract,
                                       'template' => new_template)
      ConvertWebsiteAgentTemplateForMerge.new.down
      agent.reload
      expect(agent.options).to include('extract' => reverted_extract,
                                       'template' => reverted_template)
    end
  end
end
