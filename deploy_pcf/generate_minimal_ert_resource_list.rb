#!/usr/bin/env ruby

require 'json'

contents = File.read(ARGV[0])
json = JSON.parse(contents)
instances_to_modify = {}
json['resources'].each do |resource|
  if resource['instances_best_fit'] > 1
    instances_to_modify[resource['identifier']] = {instances: 1}
  end
end

File.open('modified_resources.json','w') do |f|
  f.write(instances_to_modify.to_json)
end
