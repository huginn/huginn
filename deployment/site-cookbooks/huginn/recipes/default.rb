include_recipe 'apt'
include_recipe 'build-essential'
include_recipe 'huginn::ruby'

user "huginn" do
  system true
  home "/home/huginn"
  password "$6$ZwO6b.6tij$SMa8UIwtESGDxB37NwHsct.gJfXWmmflNbH.oypwJ9y0KkzMkCdw7D14iK7GX9C4CWSEcpGOFUow7p01rQFu5."
  supports :manage_home => true
  shell "/bin/bash"
end

group "sudo"

group "sudo" do
   action :modify
   members "huginn"
   append true
end

group "huginn" do
  members ["huginn"]
end

bash "Setting huginn user with NOPASSWD option" do
  cwd "/etc/sudoers.d"
  code <<-EOH
    touch huginn && chmod 0440 huginn 
    echo "huginn ALL=(ALL) NOPASSWD:ALL" >> huginn
  EOH
end

