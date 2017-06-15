module UsersHelper
  def user_account_state(user)
    if !user.active?
      content_tag :span, 'inactive', class: 'label label-danger'
    elsif user.access_locked?
      content_tag :span, 'locked', class: 'label label-danger'
    elsif ENV['REQUIRE_CONFIRMED_EMAIL'] == 'true' && !user.confirmed?
      content_tag :span, 'unconfirmed', class: 'label label-warning'
    else
      content_tag :span, 'active', class: 'label label-success'
    end
  end
end
