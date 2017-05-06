#!/usr/bin/env ruby

`git fetch upstream`
`git checkout master`
`git rebase upstream/master`
# `git checkout master && git merge upstream/master`