require 'octokit'
require 'yaml'

if ARGV.empty?
  puts "Please pass me YAML config file"
  puts "Usage: ruby update_tracker_service.rb <config.yml>"
  exit
end
config = YAML.load(File.open(ARGV[0]))

@client = Octokit::Client.new(access_token: config['github_token'])
@client.auto_paginate = true

service_name = 'pivotaltracker'
config_hash = {:token => config['tracker_token']}
repos = config['repos']
repos.each do |repo|
  hook_array = @client.hooks("#{repo}").select { |hook| hook.name == service_name}
  id = hook_array.first.id
  puts "Updating repo: #{repo} service: #{service_name} with new token"
  @client.edit_hook("#{repo}", id, service_name, config_hash)
end


puts "Testing hook changes ..... "
#just little time for services to refresh connections
sleep(10)

@client2 = Octokit::Client.new(access_token: config['github_token'])
@client2.auto_paginate = true

repos.each do |repo|
  hook_array = @client2.hooks("#{repo}").select { |hook| hook.name == service_name}
  id = hook_array.first.id
  # seems like only calling it twice give you updated status
  @client2.test_hook("#{repo}", id)
  @client2.test_hook("#{repo}", id)
  if @client2.hooks("#{repo}").select { |hook| hook.name == service_name}.first.last_response.status == 'misconfigured'
    puts "hook config failed for: #{repo}"
  else
    puts "hook config completed for: #{repo}"
  end
end

