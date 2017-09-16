## Update an existing Heroku deployment

Once you've run `bin/setup_heroku`, you should have 'huginn/huginn' as a remote in git.  (Check with `git remote -v`.)  Now, you can update your Heroku installation with the following commands:

```sh
git fetch origin
git merge origin/master
git push -f heroku master # note: this will wipe out any code changes that only exist on Heroku!
heroku run rake db:migrate # this will migrate the database to the latest state (not needed for every update, but always safe to run)
```
