# include_recipe 'sudo'

group "huginn" do
  # members ["huginn"]
  action :create
end

user "huginn" do
  system true
  home "/home/huginn"
  password "$6$ZwO6b.6tij$SMa8UIwtESGDxB37NwHsct.gJfXWmmflNbH.oypwJ9y0KkzMkCdw7D14iK7GX9C4CWSEcpGOFUow7p01rQFu5."
  supports :manage_home => true
  shell "/bin/bash"
  gid "huginn"
end

# # https://github.com/opscode-cookbooks/sudo
# sudo "huginn" do
#   user      "huginn"
#   commands  ["ALL"]
#   nopasswd true
#   defaults ['!requiretty']
# end

bash "Setting huginn user with NOPASSWD option" do
  cwd "/etc/sudoers.d"
  code <<-EOH
    touch huginn && chmod 0440 huginn
    echo "huginn ALL=(ALL) NOPASSWD:ALL" > huginn
    echo "Defaults:huginn !requiretty" >> huginn
  EOH
end
