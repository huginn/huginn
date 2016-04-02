# Update

You can also use [Capistrano](./capistrano.md) to keep your installation up to date.

### 0. Ensure depencies are up to date

```
cd /home/huginn/huginn
sudo bundle exec rake production:check
```

### 1. Stop server

```
sudo bundle exec rake production:stop
```

### 2. Store the current version

```
export OLD_VERSION=`git rev-parse HEAD`
```

### 3. Update the code

Back up changed files

```
sudo -u huginn -H cp Procfile Procfile.bak
```

Get the new code
```
sudo -u huginn -H git fetch --all
sudo -u huginn -H git checkout -- Procfile
sudo -u huginn -H git checkout master
sudo -u huginn -H git pull
```

Restore backed up files

```
sudo -u huginn -H cp Procfile.bak Procfile
```

### 4. Install gems, migrate and precompile assets

```
cd /home/huginn/huginn

sudo -u huginn -H bundle install --deployment --without development test

# Run database migrations
sudo -u huginn -H bundle exec rake db:migrate RAILS_ENV=production

# Clean up assets and cache
sudo -u huginn -H bundle exec rake assets:clean assets:precompile tmp:cache:clear RAILS_ENV=production

```

### 5. Update the Procfile

Check for changes made to the default `Procfile`
```
sudo -u huginn -H git diff $OLD_VERSION..master Procfile
```

Update your `Procfile` if the default options of the version you are using changed
```
sudo -u huginn -H editor Procfile
```

### 6. Update the .env file

Check for changes made to the example `.env`
```
sudo -u huginn -H git diff $OLD_VERSION..master .env.example
```

Update your `.env` with new options or changed defaults
```
sudo -u huginn -H editor .env
```


### 7. Export init script and start Huginn

```
# Export the init script
sudo bundle exec rake production:export
```

