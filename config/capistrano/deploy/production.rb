# Simple Role Syntax
# ==================
# Supports bulk-adding hosts to roles, the primary server in each group
# is considered to be the first unless any hosts have the primary
# property set.  Don't declare `role :all`, it's a meta role.

# role :app, %w{huginn@huginn.example.net}
# role :web, %w{huginn@huginn.example.net}
# role :db,  %w{huginn@huginn.example.net}


# Extended Server Syntax
# ======================
# This can be used to drop a more detailed server definition into the
# server list. The second argument is a, or duck-types, Hash and is
# used to set extended properties on the server.

# server 'example.com', user: 'deploy', roles: %w{web app}, my_property: :my_value
server 'huginn.devalias.net', user: 'huginn', roles: %w{web app db}, :primary => true

# Capistrano::UnicornNginx (https://github.com/bruno-/capistrano-unicorn-nginx)
set :nginx_server_name, 'huginn.devalias.net' # Comment this line to default to IP address
# Ignore this if you do not need SSL
# set :nginx_use_ssl, true
# set :nginx_upload_local_cert, true
# set :nginx_ssl_cert_local_path, "/path/to/ssl_cert.crt"
# set :nginx_ssl_cert_key_local_path, "/path/to/ssl_cert.key"
# set :unicorn_workers, 2

# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult[net/ssh documentation](http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start).
#
# Global options
# --------------
#  set :ssh_options, {
#    keys: %w(/home/rlisowski/.ssh/id_rsa),
#    forward_agent: false,
#    auth_methods: %w(password)
#  }
#
# And/or per server (overrides global)
# ------------------------------------
# server 'example.com',
#   user: 'user_name',
#   roles: %w{web app},
#   ssh_options: {
#     user: 'user_name', # overrides user setting above
#     keys: %w(/home/user_name/.ssh/id_rsa),
#     forward_agent: false,
#     auth_methods: %w(publickey password)
#     # password: 'please use keys'
#   }
server 'huginn.devalias.net',
  user: 'huginn',
  roles: %w{web app db},
  ssh_options: {
    # user: 'huginn', # overrides user setting above
    keys: %w(/Users/alias/.ssh/digitalocean_huginn_rsa),
    forward_agent: true,
    auth_methods: %w(publickey password)
    # password: 'please use keys'
  }
