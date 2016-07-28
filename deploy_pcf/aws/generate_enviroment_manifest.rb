#!/usr/bin/env ruby

require 'yaml'
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

def get_ops_manager_public_ip
  `aws ec2 allocate-address --output text | awk '{print $2}'`.chomp
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

def load_variable_template(template_path='variable_template.yml', env_directory=nil)
  template_var = YAML.load_file(template_path)
  stack_data = get_cloudformation_stack()
  variable_map = {}
  template_var.each do |key, value|
    if key.include?"env-"
      if ! key.include? "key-"
        raise_missing_var_error(value) if ENV[value].nil?
        key_data = key.split("env-")[1]
        variable_map[key_data] = ENV[value]
      else
        key_data = key.split("key-")[1]
        #environment_yml_git_repo resource will be named as `environment-ymls` in the pipeline
        key_path =  env_directory + "/" + ENV[value]
        add_ssh_private_key("environment.yml.mustache", key_path)
      end
    elsif key.include? "awscli-"
      key_data = key.split("awscli-")[1]
      variable_map[key_data] = send(value)
    elsif key.include? "import-ssl"
      next if value != true
      add_ssl_cert_and_key("environment.yml.mustache", env_directory)
    else
      data = stack_data[value]
      raise_missing_var_error(value, false) if data.nil?
      variable_map[key] = data
    end
  end
  variable_map.to_yaml
end

def add_ssl_cert_and_key(env_temp_path, env_directory)
  ssl_cert_path = Dir.glob("#{env_directory}/*.pem").first
  ssl_key_path = Dir.glob("#{env_directory}/*.key").first

  ssl_cert_string = File.read(ssl_cert_path)
  ssl_cert_string = YAML.dump({"ssl_certificate" => ssl_cert_string})
  ssl_cert_string = ssl_cert_string.gsub(/^---/,'')
  ssl_cert_string = ssl_cert_string.gsub('ssl_certificate:', 'ssl_certificate: &ssl_certificate')

  ssl_key_string = File.read(ssl_key_path)
  ssl_key_string = YAML.dump({"ssl_private_key" => ssl_key_string})
  ssl_key_string = ssl_key_string.gsub(/^---/,'')
  ssl_key_string = ssl_key_string.gsub('ssl_private_key:', 'ssl_private_key: &ssl_private_key')

  environment_yml_string = File.read(env_temp_path)
  yaml_string = ssl_cert_string + "\n" + ssl_key_string + "\n\n" + environment_yml_string
  File.open(env_temp_path, 'w') { |f| f.puts yaml_string }
end

def add_ssh_private_key(env_temp_path, private_key_path)
  private_key_string = File.read(private_key_path)
  private_key_string = YAML.dump({"ssh_key" => private_key_string})
  private_key_string = private_key_string.gsub(/^---/,'')
  private_key_string = private_key_string.gsub('ssh_key:', 'ssh_key: &ssh_key')
  environment_yml_string = File.read(env_temp_path)
  yaml_string = private_key_string + "\n\n" + environment_yml_string
  File.open(env_temp_path, 'w') { |f| f.puts yaml_string }
end

def create_variable_file(path="./")
  if ARGV.length == 0
    puts "ERROR: Need private key path"
    exit 1
  end
  variable_data = load_variable_template('variable_template.yml', ARGV[0])
  File.write("#{path}/variable.yml", variable_data)
  puts "Vaiable file created: \n#{variable_data}"
end

create_variable_file()
