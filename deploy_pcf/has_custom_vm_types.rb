#!/usr/bin/env ruby

require 'json'

default_vm_types = JSON.parse(File.read(ARGV[0]))['vm_types']
custom_vm_types = JSON.parse(File.read(ARGV[1]))

shared_vm_types = default_vm_types & custom_vm_types
if shared_vm_types != custom_vm_types
  puts false
  exit(0)
end

puts true
