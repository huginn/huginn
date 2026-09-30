require 'rails_helper'

describe 'layouts/navigation', type: :helper do
  def render_navigation
    allow(helper).to receive(:image_path).and_return('/images/spinner-arrows.gif')
    render partial: 'layouts/navigation'
  end

  it 'renders signed-out navigation labels from locale keys' do
    allow(helper).to receive(:user_signed_in?).and_return(false)

    html = render_navigation

    expect(html).to include(I18n.t('layouts.navigation.toggle_navigation'))
    expect(html).to include(I18n.t('layouts.navigation.brand'))
    expect(html).to include(I18n.t('layouts.navigation.account'))
    expect(html).to include(I18n.t('layouts.navigation.sign_up'))
    expect(html).to include(I18n.t('layouts.navigation.about'))
    expect(html).to include(I18n.t('layouts.navigation.login'))
    expect(html).not_to include(I18n.t('layouts.navigation.agents'))
    expect(html).not_to include(I18n.t('layouts.navigation.logout'))
  end

  it 'renders signed-in navigation labels from locale keys' do
    allow(helper).to receive_messages(
      user_signed_in?: true,
      current_user: users(:bob),
      current_page?: false
    )
    allow(helper).to receive(:session).and_return({})

    html = render_navigation

    %w[
      agents new_agent run_event_propagation view_diagram scenarios events
      credentials services search event_count account about logout
    ].each do |key|
      expect(html).to include(I18n.t("layouts.navigation.#{key}"))
    end
    expect(html).not_to include(I18n.t('layouts.navigation.job_management'))
    expect(html).not_to include(I18n.t('layouts.navigation.switch_back_to_admin_user'))
  end

  it 'renders admin navigation labels from locale keys' do
    allow(helper).to receive_messages(
      user_signed_in?: true,
      current_user: users(:jane),
      current_page?: false
    )
    allow(helper).to receive(:session).and_return({ original_admin_user_id: users(:bob).id })

    html = render_navigation

    expect(html).to include(I18n.t('layouts.navigation.switch_back_to_admin_user'))
    expect(html).to include(I18n.t('layouts.navigation.job_management'))
    expect(html).to include(I18n.t('layouts.navigation.user_management'))
    expect(html).to include(users(:jane).username)
  end
end
