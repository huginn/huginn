#!/usr/bin/env ruby

in_file = ARGV.shift
out_file = ARGV.shift || "decrypted_backup.tar"

puts "About to decrypt #{in_file} and write it to #{out_file}."

cmd = "bundle exec backup decrypt --encryptor openssl --base64 --salt --in #{in_file} --out #{out_file}"
puts "Executing: #{cmd}"
puts `#{cmd}`
