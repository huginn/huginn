Run scripts or jobs on a weekly basis
=====================================
Any scripts or jobs added to this directory will be run on a scheduled basis
(weekly) using run-parts.

run-parts ignores any files that are hidden or dotfiles (.*) or backup
files (*~ or *,)  or named *.{rpmsave,rpmorig,rpmnew,swp,cfsaved} and handles
the files named jobs.deny and jobs.allow specially.

In this specific example, the chronograph script is the only script or job file
executed on a weekly basis (due to white-listing it in jobs.allow). And the
README and chrono.dat file are ignored either as a result of being black-listed
in jobs.deny or because they are NOT white-listed in the jobs.allow file.

For more details, please see ../README.cron file.

