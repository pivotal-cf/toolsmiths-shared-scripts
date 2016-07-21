#!/usr/bin/env ruby

require 'optparse'
require 'YAML'
require 'json'

def raise_missing_var_error(var_name=nil, env=true)
  if env
    data = "Environment variable missing: #{var_name}"
  else
    data = "Missing vaiable : #{var_name}"
  end
  raise data
end

def get_iam_profile_name(stack_name=nil)
 if stack_name.nil?
    raise_missing_var_error('AWS_ENVIRONMENT_NAME') if ENV['AWS_ENVIRONMENT_NAME'].nil?
    stack_name = ENV['AWS_ENVIRONMENT_NAME']
  end
  `aws iam list-instance-profiles > instance_profiles.json`
  instance_data = JSON.parse(File.read('instance_profiles.json'))['InstanceProfiles']
  instance_data.each do |instance|
    profile_name = instance['InstanceProfileName']
    if profile_name.include? stack_name
      puts "Matching profile found: #{profile_name}"
      return profile_name
    end
  end
  raise "No macthing InstanceProfileName found for: #{stack_name}"
end

def get_cloudformation_stack(stack_name=nil)
  if stack_name.nil?
    raise_missing_var_error('AWS_ENVIRONMENT_NAME') if ENV['AWS_ENVIRONMENT_NAME'].nil?
    stack_name = ENV['AWS_ENVIRONMENT_NAME']
  end
  `aws cloudformation describe-stacks --stack-name #{stack_name} > stack_data.json`
  stack_data = JSON.parse(File.read('stack_data.json'))['Stacks'].first
  parameters = {}
  stack_data['Outputs'].each do |hash_data|
    parameters[hash_data['OutputKey']] = hash_data['OutputValue']
  end
  return parameters
end

def load_variable_template(path='variable_template.yml')
  template_var = YAML.load_file(path)
  stack_data = get_cloudformation_stack()
  variable_map = {}
  template_var.each do |key, value|
    if key.include?"env-"
      raise_missing_var_error(value) if ENV[value].nil?
      key_data = key.split("env-")[1]
      variable_map[key_data] = ENV[value]
    elsif key.include? "cloudformation-"
      profile_name = get_iam_profile_name()
      key_data = key.split("cloudformation-")[1]
      variable_map[key_data] = profile_name
    else
      data = stack_data[value]
      raise_missing_var_error(value, false) if data.nil?
      variable_map[key] = data
    end
  end
  variable_map.to_yaml
end

def create_variable_file(path="./")
  variable_data = load_variable_template()
  File.write("#{path}/variable.yml", variable_data)
  puts "Vaiable file created: \n#{variable_data}"
end

create_variable_file()
