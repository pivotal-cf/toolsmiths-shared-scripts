#!/usr/bin/env ruby

require 'optparse'
include Process
require 'pry'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: deploy_pcf.rb [options]"

  opts.on('-d', '--dry-run') do |dry_run|
    options[:dry_run] = dry_run
  end
  opts.on('-D', '--environment-directory [DIR]') do |environment_directory|
    options[:environment_directory] = environment_directory
  end
  opts.on('-N', '--environment-name [NAME]') do |environment_name|
    options[:environment_name] = environment_name
  end
  opts.on('-O', '--ops-manager [PATH]') do |ops_manager|
    options[:ops_manager] = ops_manager
  end
  opts.on('-V', '--ops-manager-version [VERSION]') do |ops_manager_version|
    options[:ops_manager_version] = ops_manager_version
  end
  opts.on('-E', '--elastic-runtime [PATH]') do |elastic_runtime|
    options[:elastic_runtime] = elastic_runtime
  end
  opts.on('-W', '--elastic-runtime-version [VERSION]') do |elastic_runtime_version|
    options[:elastic_runtime_version] = elastic_runtime_version
  end
  opts.on('-S', '--stemcell [PATH]') do |stemcell|
    options[:stemcell] = stemcell
  end
  opts.on('-H', '--headless') do |headless|
    options[:headless] = headless
  end
  opts.on('-I', '--interactive') do |interactive|
    options[:interactive] = interactive
  end
  opts.on('-h', '--help') do |help|
    puts opts
    exit
  end

  @opts = opts
end.parse!

def attempt(cmd)
  puts "*" * 72
  puts "running #{cmd}..."
  puts Time.now
  puts "*" * 72

  pid = Process.spawn("time " + cmd)
  trap('SIGINT') { Process.kill('HUP', pid) }
  pid, status = waitpid2(pid)
  exit_status = status.exitstatus

  case exit_status
    when 0
      puts "SUCCESS: #{cmd} completed"
    when 1
      puts "FAILED:  #{cmd}"
      exit 1
    else
      puts "Ooh, got a weird exit status: #{exit_status}"
  end
end

if options.empty?
  puts @opts
  exit
end

environment = options[:environment_name]
options[:environment_directory] ||= "#{ENV['HOME']}/workspace/deployments-toolsmiths/vcenter/environments/config"

if options[:headless]
  # xvfb server can only run one at a time - use -a flag to automatically find a free server number
  xvfb = "xvfb-run -a "
end

cmds = [
  "bundle exec rake opsmgr:destroy[#{environment}]",
  "bundle exec rake opsmgr:install[#{environment},#{options[:ops_manager]}]",
  "#{xvfb}bundle exec rake opsmgr:add_first_user[#{environment},#{options[:ops_manager_version]}]",
  "#{xvfb}bundle exec rake opsmgr:microbosh:configure[#{environment},#{options[:ops_manager_version]}]",
  "#{xvfb}bundle exec rake opsmgr:trigger_install[#{environment},#{options[:ops_manager_version]},40]",
  "#{xvfb}bundle exec rake opsmgr:product:upload_add[#{environment},#{options[:ops_manager_version]},#{options[:elastic_runtime]},cf]",
  "#{xvfb}bundle exec rake ert:configure[#{environment},#{options[:elastic_runtime_version]},#{options[:ops_manager_version]}]",
  "#{xvfb}bundle exec rake opsmgr:trigger_install[#{environment},#{options[:ops_manager_version]},240]"
]


if options[:interactive]
  cmds_to_run = []
  puts "Do you want to run: (y/n) "
  cmds.each do |cmd|
    puts "  " + cmd
    if STDIN.gets.upcase.include? 'Y'
      cmds_to_run << cmd
    end
  end
  puts "Run the following?"
  puts cmds_to_run
  if STDIN.gets.upcase.include? 'Y'
    cmds = cmds_to_run
  else
    exit
  end
end


if options[:dry_run]
  puts cmds.join(" &&\\\n")
  exit
end

ENV['ENV_DIRECTORY'] = options[:environment_directory]

runtime_dir=ENV['OLDPWD'] + "/p-runtime"
Dir.chdir(runtime_dir)
result = system("bundle")
unless result
  puts "Couldn't run bundle"
  exit 1
end

cmds.each { |cmd| attempt cmd }
