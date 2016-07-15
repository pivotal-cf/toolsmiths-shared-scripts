#!/usr/bin/env ruby

require 'yaml'
require 'fileutils'

DIR=ARGV[0]
PATH_TO_MANIFEST=ARGV[1]

if DIR.nil? or PATH_TO_MANIFEST.nil?
  puts "Usage: ./dump_cf_certs_and_keys_to_yaml.rb <DIRECTORY OF KEYS AND CERTS> <PATH TO MANIFEST YAML>"
  exit
end

hash = {}
files = Dir[File.expand_path(DIR) + '/*']
files.each do |file|
  hash[File.basename(file)] = File.read(file)
end

yaml_string = hash.to_yaml.gsub!(/^---/,'')

# Make each key a yaml pointer
files.each {|file| yaml_string.gsub!(/^#{File.basename(file)}:/, File.basename(file) + ": &#{File.basename(file)}")}
yaml_string = "\n### generated keys start here ###\n" + yaml_string +"\n### generated keys end here ###\n"
puts "inserting certificates and keys into deployment manifest"

manifest_lines = File.readlines(PATH_TO_MANIFEST)
start_keys_index = manifest_lines.find_index("### generated keys start here ###\n")
end_keys_index = manifest_lines.find_index("### generated keys end here ###\n")
manifest_lines.slice! start_keys_index..end_keys_index if !start_keys_index.nil? && !end_keys_index.nil?

temp_manifest=File.open("#{PATH_TO_MANIFEST}.tmp", 'w')
manifest_lines.each do |line|
  temp_manifest << line
  if line.downcase =~ /^director_uuid/
    temp_manifest << yaml_string
  end
end
temp_manifest.close
FileUtils.mv("#{PATH_TO_MANIFEST}.tmp", PATH_TO_MANIFEST)
