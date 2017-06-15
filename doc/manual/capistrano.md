# Deploy updates via Capistrano

After you followed the [manual installation guide](installation.md) it is simple to push updates to your huginn instance using capistrano.

### 1. Ensure you have SSH access to your server via the huginn user

Either set a password for the huginn user or add your public SSH key:

    # Set password
    sudo passwd huginn

    # Or add a SSH key
    sudo -u huginn -H mkdir -p /home/huginn/.ssh
    sudo -u huginn -H editor /home/huginn/.ssh/authorized_keys
    sudo -u huginn -H chmod -R 700 /home/huginn/.ssh

### 2. Configure Capistrano on your local machine

Add Capistrano configuration to you local `.env`:

    CAPISTRANO_DEPLOY_SERVER=<IP or FQDN of your server>
    CAPISTRANO_DEPLOY_USER=huginn
    CAPISTRANO_DEPLOY_REPO_URL=https://github.com/cantino/huginn.git


### 3. Run Capistrano

You can now run Capistrano and update your server:

    cap production deploy

If you want to deploy a different branch, pass it as environment variable:

    cap production deploy BRANCH=awesome-feature

### Changes to remote .env and Procfile

If you want to change the `.env`, `Procfile` or `config/unicorn.rb` of your installation you still need to do it on your server, do not forget to export the init scripts after your are done:

    cd /home/huginn/huginn
    # Whichever you want to change
    sudo -u huginn -H editor Procfile
    sudo -u huginn -H editor .env
    sudo -u huginn -H editor config/unicorn.rb
    # Export init scripts and restart huginn
    sudo rake production:export

