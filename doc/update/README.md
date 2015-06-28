# Update

### 0. Stop server

```
sudo stop huginn
```

### 1. Store the current version

```
cd /home/huginn/huginn
export OLD_VERSION=`git rev-parse HEAD`
```

### 2. Update the code

Back up changed files

```
sudo -u huginn -H cp Procfile Procfile.bak
```

Get the new code
```
sudo -u huginn -H git fetch --all
sudo -u huginn -H git checkout -- db/schema.rb Procfile
sudo -u huginn -H git checkout master
sudo -u huginn -H git pull
```

Restore backed up files

```
sudo -u huginn -H cp Procfile.bak Procfile
```

### 3. Install gems, migrate and precompile assets

```
cd /home/huginn/huginn

sudo -u huginn -H bundle install --deployment --without development test

# Run database migrations
sudo -u huginn -H bundle exec rake db:migrate RAILS_ENV=production

# Clean up assets and cache
sudo -u huginn -H bundle exec rake assets:clean assets:precompile cache:clear RAILS_ENV=production

```

### 4. Update the Procfile

Check for changes made to the default `Procfile`
```
sudo -u huginn -H git diff $OLD_VERSION..master Procfile
```

Update your `Procfile` if the default options of the version you are using changed
```
sudo -u huginn -H editor Procfile
```

### 5. Update the .env file

Check for changes made to the example `.env`
```
sudo -u huginn -H git diff $OLD_VERSION..master .env.example
```

Update your `.env` with new options or changed defaults
```
sudo -u huginn -H editor .env
```


### 6. Export init script and start huginn

```
# Export the init script
sudo rm /etc/init/huginn*
sudo foreman export upstart -a huginn /etc/init
# Start huginn
sudo start huginn
```

