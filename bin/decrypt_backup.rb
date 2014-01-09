#!/usr/bin/env ruby

# If you're using the backup gem, described on the Huginn wiki and at doc/deployment/backup, then you can use this
# utility to decrypt backups.

in_file = ARGV.shift
out_file = ARGV.shift || "decrypted_backup.tar"

puts "About to decrypt #{in_file} and write it to #{out_file}."

cmd = "bundle exec backup decrypt --encryptor openssl --base64 --salt --in #{in_file} --out #{out_file}"
puts "Executing: #{cmd}"
puts `#{cmd}`
