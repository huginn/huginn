require 'rails_helper'

describe Admin::UsersController, type: :routing do
  it 'only routes impersonation actions via POST' do
    expect(post: '/admin/users/1/switch_to_user').to route_to('admin/users#switch_to_user', id: '1')
    expect(post: '/admin/users/switch_back').to route_to('admin/users#switch_back')
    expect(get: '/admin/users/1/switch_to_user').not_to be_routable
    expect(get: '/admin/users/switch_back').not_to be_routable
  end
end
