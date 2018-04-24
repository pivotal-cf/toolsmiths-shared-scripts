#!/usr/bin/env ruby

require 'json'

default_vm_types_file = File.read(ARGV[0])
custom_vm_types_file = ARGV[1].nil? ? '{}' : File.read(ARGV[1])

default_vm_types_hash = JSON.parse(default_vm_types_file)
custom_vm_types_list = JSON.parse(custom_vm_types_file)

if custom_vm_types_list.nil?
  p 'No custom vm types provided!'
else
  custom_vm_types_list.each { |vm| default_vm_types_hash["vm_types"].push(vm) } 
end


File.open('modified_vm_types.json','w') do |f|
  f.write(default_vm_types_hash.to_json)
end
