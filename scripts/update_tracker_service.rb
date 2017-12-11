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
  if hook_array.length > 0
    id = hook_array.first.id
    puts "Updating repo: #{repo} service: #{service_name} with new token"
    @client.edit_hook("#{repo}", id, service_name, config_hash)
  else
    puts "Adding service: #{service_name} to repo: #{repo} with new token"
    @client.create_hook("#{repo}", service_name, config_hash)
  end
end


puts "Testing hook changes ..... "

@client2 = Octokit::Client.new(access_token: config['github_token'])
@client2.auto_paginate = true

repos.each do |repo|
  hook_array = @client2.hooks("#{repo}").select { |hook| hook.name == service_name}
  id = hook_array.first.id

# Incremental backoff since Github API doesn't immediately reflect changes.

  i = 1
  while i <= 4 do
    @client2.test_hook("#{repo}", id)
    sleep (2*i)

    if @client2.hooks("#{repo}").select { |hook| hook.name == service_name}.first.last_response.status == 'misconfigured'
      i += 1
      if i == 5
        puts "hook config failed for #{repo}"
      end
    else
      puts "hook config completed for: #{repo}"
      i = 5
    end
  end

end

