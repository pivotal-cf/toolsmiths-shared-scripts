#!/usr/bin/env ruby

require 'optparse'
include Process
require 'pry'

class String
  def green;          "\e[32m#{self}\e[0m" end
  def red;            "\e[31m#{self}\e[0m" end
  def cyan;           "\e[36m#{self}\e[0m" end
end

def attempt(cmd)
  puts "*".cyan * 72
  puts "running #{cmd}...".cyan
  puts Time.now.to_s.cyan
  puts "*".cyan * 72

  pid = Process.spawn("time " + cmd)
  trap('SIGINT') { Process.kill('HUP', pid) }
  pid, status = waitpid2(pid)
  exit_status = status.exitstatus

  case exit_status
    when 0
      puts "SUCCESS: #{cmd} completed".green
    when 1
      puts "FAILED:  #{cmd}".red
      exit 1
    else
      puts "Ooh, got a weird exit status: #{exit_status}".red
  end
end

def download_stemcell(path_to_product_tarball,iaas)
  puts "Finding stemcell version for #{path_to_product_tarball}".cyan
  if `uname -s`.chomp == "Darwin"
    `jar -xf #{path_to_product_tarball} metadata/cf.yml && cat metadata/cf.yml | grep -A3 stemcell | grep version | grep -oE "[0-9\.]+" > stemcell_version`
  else
    `unzip #{path_to_product_tarball} metadata/cf.yml && cat metadata/cf.yml | grep -A3 stemcell | grep version | grep -oE "[0-9\.]+" > stemcell_version`
  end
  version = `cat stemcell_version`.chomp!
  puts "Downloading stemcell version #{version} for #{iaas}".cyan

  case iaas
  when 'vsphere'
    `wget --content-disposition https://bosh.io/d/stemcells/bosh-vsphere-esxi-ubuntu-trusty-go_agent?v=#{version}`
  when 'aws'
    `wget --content-disposition https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent?v=#{version}`
  when 'openstack'
    `wget --content-disposition https://bosh.io/d/stemcells/bosh-openstack-kvm-ubuntu-trusty-go_agent-raw?v=#{version}`
  else
    raise "cannot find iaas named #{iaas}".red
  end
  file_name = `ls *bosh-stemcell-#{version}-#{iaas}*`.split("\n").first
  File.expand_path(file_name)
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: deploy_pcf.rb [options]"

  opts.on('-d', '--dry-run') do |dry_run|
    options[:dry_run] = dry_run
  end
  opts.on('-D', '--environment-directory [DIR]') do |environment_directory|
    options[:environment_directory] = File.expand_path(environment_directory)
  end
  opts.on('-N', '--environment-name [NAME]') do |environment_name|
    options[:environment_name] = environment_name
  end
  opts.on('-O', '--ops-manager [PATH]') do |ops_manager|
    options[:ops_manager] = File.expand_path(ops_manager)
  end
  opts.on('-V', '--ops-manager-version [VERSION]') do |ops_manager_version|
    options[:ops_manager_version] = ops_manager_version
  end
  opts.on('-E', '--elastic-runtime [PATH]') do |elastic_runtime|
    options[:elastic_runtime] = File.expand_path(elastic_runtime)
  end
  opts.on('-W', '--elastic-runtime-version [VERSION]') do |elastic_runtime_version|
    options[:elastic_runtime_version] = elastic_runtime_version
  end
  opts.on('-P', '--p-runtime-directory [DIR]') do |p_runtime_directory|
    options[:p_runtime_directory] = p_runtime_directory
  end
  opts.on('-S', '--stemcell [PATH]') do |stemcell|
    options[:stemcell] = File.expand_path(stemcell)
  end
  opts.on('-H', '--headless') do |headless|
    options[:headless] = headless
  end
  opts.on('-I', '--interactive') do |interactive|
    options[:interactive] = interactive
  end
  opts.on('-i', '--iaas [IAAS]') do |iaas|
    options[:iaas] = iaas
  end
  opts.on('-C', '--commands [CMDS]') do |commands|
    p commands
    options[:commands] = commands
  end
  opts.on('-h', '--help') do |help|
    puts opts
    exit
  end

  @opts = opts
end.parse!


if options.empty?
  puts @opts
  exit
end

environment = options[:environment_name]
options[:environment_directory] ||= "#{ENV['HOME']}"
options[:ops_manager_version] ||= ENV['OPSMGR_VERSION']
options[:elastic_runtime_version] ||= ENV['ERT_VERSION']
options[:iaas] ||= 'vsphere'

if options[:ops_manager_version] == 'latest'
  download_pivnet_file = File.expand_path(File.dirname(__FILE__)) + "/download-from-pivnet.rb"
  options[:ops_manager_version] = `#{download_pivnet_file} --print-latest ops-manager#{options[:ops_manager_version]}`
end

if options[:elastic_runtime_version] == 'latest'
  download_pivnet_file = File.expand_path(File.dirname(__FILE__)) + "/download-from-pivnet.rb"
  options[:elastic_runtime_version] = `#{download_pivnet_file} --print-latest elastic-runtime#{options[:elastic_runtime_version]}`
end

options[:ops_manager_version] = options[:ops_manager_version].match('[0-9]+\.[0-9]').to_s if options[:ops_manager_version]
options[:elastic_runtime_version] = options[:elastic_runtime_version].match('[0-9]+\.[0-9]').to_s if options[:elastic_runtime_version]

# xvfb server can only run one at a time - use -a flag to automatically find a free server number
xvfb = "xvfb-run -a " if options[:headless]

options[:stemcell] = download_stemcell(options[:elastic_runtime],options[:iaas]) if options[:stemcell].nil? && options[:elastic_runtime]

cmds = [
  "bundle exec rake opsmgr:destroy[#{environment}]",
  "bundle exec rake opsmgr:install[#{environment},#{options[:ops_manager]}]",
  "#{xvfb}bundle exec rake opsmgr:add_first_user[#{environment},#{options[:ops_manager_version]}]",
  "#{xvfb}bundle exec rake opsmgr:microbosh:configure[#{environment},#{options[:ops_manager_version]}]",
  "#{xvfb}bundle exec rake opsmgr:trigger_install[#{environment},#{options[:ops_manager_version]},240]",
  "#{xvfb}bundle exec rake opsmgr:product:upload_add[#{environment},#{options[:ops_manager_version]},#{options[:elastic_runtime]},cf]",
  "#{xvfb}bundle exec rake opsmgr:product:import_stemcell[#{environment},#{options[:ops_manager_version]},#{options[:stemcell]},cf]",
  "#{xvfb}bundle exec rake ert:configure[#{environment},#{options[:elastic_runtime_version]},#{options[:ops_manager_version]}]",
  "#{xvfb}bundle exec rake ert:create_aws_dbs[#{environment}]",
  "#{xvfb}bundle exec rake ert:configure_external_dbs[#{environment},#{options[:elastic_runtime_version]},#{options[:ops_manager_version]}]",
  "#{xvfb}bundle exec rake ert:configure_external_file_storage[#{environment},#{options[:elastic_runtime_version]},#{options[:ops_manager_version]}]",
  "#{xvfb}bundle exec rake opsmgr:trigger_install[#{environment},#{options[:ops_manager_version]},240]"
]

if options[:commands]
  commands_to_run = []
  commands = options[:commands].split(',')
  commands.each do |command|
    commands_to_run << cmds.select {|cmd| cmd.include? command}.first
  end
  cmds = commands_to_run
end

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
default_p_runtime_directory = File.expand_path('../..', File.dirname(__FILE__)) + "/p-runtime"
runtime_dir = options.fetch(:p_runtime_directory, default_p_runtime_directory)

Dir.chdir(runtime_dir)
result = system("bundle")
unless result
  puts "Couldn't run bundle".red
  exit 1
end

cmds.each { |cmd| attempt cmd }
