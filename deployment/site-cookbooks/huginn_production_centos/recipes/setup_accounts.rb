# http://docs.opscode.com/resource_user.html

# https://github.com/sethvargo-cookbooks/users
# include_recipe "users"

default['huginn']['user'] = "huginn"
default['huginn']['group'] = "huginn"

huginn_user = node['huginn']['user']
huginn_group = node['huginn']['group']
huginn_user_home = "/home/#{default['huginn']['user']}"

user huginn_user do
  comment "Huginn system account"
  home huginn_user_home
  # password "$6$ZwO6b.6tij$SMa8UIwtESGDxB37NwHsct.gJfXWmmflNbH.oypwJ9y0KkzMkCdw7D14iK7GX9C4CWSEcpGOFUow7p01rQFu5."
  supports :manage_home => true
  system true
  shell "/bin/bash"
  gid "sudo"
  action :create
end

# users_manage "huginn" do
#   data_bag "users"
#   group_name huginn_group
#   group_id 10
# end

user huginn_user do
  action :lock
end

group huginn_group do
  members [huginn_user]
end

sudo huginn_user do
  commands  ['ALL']
  nopasswd true
end

ohai "reload_passwd" do
  plugin "passwd"
end


# user "huginn" do
#   system true
#   home "/home/huginn"
#   password "$6$ZwO6b.6tij$SMa8UIwtESGDxB37NwHsct.gJfXWmmflNbH.oypwJ9y0KkzMkCdw7D14iK7GX9C4CWSEcpGOFUow7p01rQFu5."
#   supports :manage_home => true
#   shell "/bin/bash"
#   gid "sudo"
# end

# group "huginn" do
#   members ["huginn"]
# end

# bash "Setting huginn user with NOPASSWD option" do
#   cwd "/etc/sudoers.d"
#   code <<-EOH
#     touch huginn && chmod 0440 huginn
#     echo "huginn ALL=(ALL) NOPASSWD:ALL" >> huginn
#   EOH
# end
