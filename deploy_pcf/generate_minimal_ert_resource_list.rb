#!/usr/bin/env ruby

require 'json'

original_resources = File.read(ARGV[0])
resource_overrides = ARGV[1].nil? ? '{}' : File.read(ARGV[1])

original_resources_json = JSON.parse(original_resources)
instances_to_modify = {}

original_resources_json['resources'].each do |resource|
  desired_resources = 0
  #"" means "Use the 'Automatic' value, stored in instances_best_fit"
  if resource['instances'] == ""
    if resource['instances_best_fit'] == ""
      puts "WARN: instances and instances_best_fit are both the empty string. This is unexpected and unhandled."
    end
    desired_resources = resource['instances_best_fit']
  else
    desired_resources = resource['instances']
  end
  if desired_resources > 1
    instances_to_modify[resource['identifier']] = {instances: 1}
  end
end

instances_to_modify.merge!(JSON.parse(resource_overrides))

File.open('modified_resources.json','w') do |f|
  f.write(instances_to_modify.to_json)
end
