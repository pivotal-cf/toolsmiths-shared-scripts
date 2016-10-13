#!/usr/bin/env ruby

require 'aws-sdk-v1'
require 'yaml'
require 'logger'
require 'open3'
require 'httparty'

def list_sequence (seq_type, deployment_name, sequence, ec2_client, logger)
  sequence_map ={}

  # start will load data from yaml file created during stop process
  if seq_type == 'start'
    instance_map = YAML.load_file("environment-repo/#{ENV['ENV_STATE_FOLDER']}/instance_data.yml")
    instance_key_list = instance_map['components']
    logger.debug("InstanceMap:#{instance_map}")
    sequence['start_sequence'].each do |component|
      job_name = component['job_name_prefix']
      all_azs = instance_key_list.select{|instance| instance.match(/^#{job_name}(-\w+-\w+|_\w+)\/\d/)}
      if !all_azs.empty?
        logger.debug("MappedInstances::ToStart:#{job_name}:#{all_azs}")
        sequence_map[job_name] = all_azs
      else
        sequence_map[job_name] = []
        logger.debug("NoInstance::ToStart:JobName:#{job_name}")
      end

    end
  else
    # stop process will create a yaml file mapping all running instances for start process
    instance_map = get_instance_map(deployment_name, ec2_client, logger)
    instance_key_list = instance_map.keys
    logger.debug("InstanceMap:#{instance_map}")
    sequence['stop_sequence'].each do |component|
      job_name = component['job_name_prefix']
      # map is based on naming suffix used for instances:
      # default: bosh will add deployment IDs as <job_name>-partition-<deployment-id>/<job-index>
      all_azs = instance_key_list.select{|instance| instance.match(/^#{job_name}(-\w+-\w+|_\w+)\/\d/)}
      if !all_azs.empty?
        logger.debug("MappedInstances::ToStop:#{job_name}:#{all_azs}")
        sequence_map[job_name] = all_azs
      else
        sequence_map[job_name] = []
        logger.debug("NoInstance::ToStop:JobName:#{job_name}")
      end
    end
  end
  return sequence_map
end

def get_instance_map(deployment_name, ec2_client, logger)
  instances = fetch_instances_for_deployment(deployment_name, ec2_client, logger)
  logger.info("CreatingInstanceMap")
  instances = instances.inject({}) { |m, i| m["#{i.tags.to_h['job']}/#{i.tags.to_h['index']}"] = i.id ; m }
  return instances
end

def fetch_instances_for_deployment(deployment_name, ec2_client, logger)
  logger.info("GettingInstance::FromAWS")
  ec2_client.instances.filter('tag:deployment', deployment_name)
end

def stop_instances(sequence, deployment_name, logger)
  logger.info("StopInstances:Deployment:#{deployment_name}:Triggered")
  job_list  = []
  sequence.each do | name, job_ids |
    job_ids.each do | job_id |
      change_instance_status(job_id, name, logger, 'stop')
      job_list << job_id
    end
  end
  store_job_ids = File.open("output/environment-repo/#{ENV['ENV_STATE_FOLDER']}/instance_data.yml", 'w')
  data = {'components' => job_list}
  store_job_ids.write(data.to_yaml)
  store_job_ids.close()
  logger.info("JobData:#{data.to_yaml}")
  git_commit(logger)
end


def start_instances(sequence, deployment_name, logger)
  logger.info("StartInstances:Deployment:#{deployment_name}:Triggered")
  sequence.each do | name, job_ids |j
    job_ids.each do | job_id |
      change_instance_status(job_id, name, logger)
    end
  end
end

def change_instance_status(job_id, name, logger, change_to='start')
  cmd = "-n start #{job_id} --force"
  if change_to == 'stop'
    cmd = "-n stop #{job_id} --hard"
  end
  logger.info("ChangingInstanceStatusTo:#{change_to}:#{job_id}")
  exec_cmd_on_ops_mgr(cmd, logger)
end

def git_commit(logger)
  `git config --global user.name #{ENV['GITHUB_USERNAME']} && git config --global user.email #{ENV['GITHUB_EMAIL']}`
  `cd output/environment-repo/ && git add #{ENV['ENV_STATE_FOLDER']}/instance_data.yml && git commit -m"Adding #{ENV['DEPLOYMENT_NAME']} instance data"`
  if $?.to_i == 0
    logger.info("InstanceDataFile:Added")
  else
    logger.error("Failed:ToAddInstanceDataFile")
  end
end

#Connect to OpsManager/Jumpbox
def exec_cmd_on_ops_mgr(cmd, logger, bosh_cmd=true)
  if bosh_cmd
    exec_cmd = "chmod 600 environment-repo/#{ENV['ENV_STATE_FOLDER']}/#{ENV['OPS_MANAGER_KEY_NAME']} && ssh  -o StrictHostKeyChecking=no -i environment-repo/#{ENV['ENV_STATE_FOLDER']}/#{ENV['OPS_MANAGER_KEY_NAME']} ubuntu@#{ENV['OPS_MANAGER_HOSTNAME']}  \"BUNDLE_GEMFILE=/home/tempest-web/tempest/web/vendor/bosh/Gemfile bundle exec bosh #{cmd}\""
  else
    exec_cmd = "chmod 600 environment-repo/#{ENV['ENV_STATE_FOLDER']}/#{ENV['OPS_MANAGER_KEY_NAME']} && ssh -o StrictHostKeyChecking=no -i environment-repo/#{ENV['ENV_STATE_FOLDER']}/#{ENV['OPS_MANAGER_KEY_NAME']} ubuntu@#{ENV['OPS_MANAGER_HOSTNAME']} \"#{cmd}\""
  end
  stdout, stderr, status = Open3.capture3(exec_cmd)
  logger.info("Open3:STDOUT:#{stdout}, Open3:STDERR:#{stderr}")
  if stderr.downcase.include? ("error (exit code 1)") || stdout.downcase.include?("did not complete")
     raise "BOSH:CMD:Failed:#{exec_cmd}"
  end
end

def target_bosh_director(logger)
  bosh_director_ip_cmd = "#{ENV['PWD']}/aws-frugal-repo/deploy_pcf/aws/aws-frugal/scripts/get_bosh_director_ip.sh #{ENV['OPS_MANAGER_HOSTNAME']} #{ENV['OPS_MANAGER_USERNAME']} #{ENV['OPS_MANAGER_PASSWORD']}"
  logger.debug("Targetting:BOSHDirector:#{bosh_director_ip_cmd}")
  stderr = false
  data, stderr, status = Open3.capture3(bosh_director_ip_cmd)
  if stderr.downcase.include? ('error')
    raise "OPSManager:GetIPError:#{stderr}"
  end
  bosh_director_data = File.open("bosh_data/BOSH_DIRECTOR_DATA.txt", 'r').read
  if bosh_director_data.lines.size == 2
    bosh_ip = bosh_director_data.lines[0].gsub(/["\n]/,'').strip()
    bosh_cred = bosh_director_data.lines[1].gsub(/["\n]/,'').strip().split("|")
    target_cmd = "-n --ca-cert #{ENV['BOSH_ROOT_CERT_PATH']} target #{bosh_ip}"
    exec_cmd_on_ops_mgr(target_cmd, logger)
    bosh_login(bosh_cred[0], bosh_cred[1], logger)
  else
    raise "BOSHDirector:BadDataFile:#{bosh_director_data}"
  end
end

def set_bosh_deployment(deployment_name,logger)
  bosh_deployment_cmd = "-n deployment /var/tempest/workspaces/default/deployments/#{deployment_name}.yml"
  exec_cmd_on_ops_mgr(bosh_deployment_cmd, logger)
  logger.info("BOSH:Deployment:Set")
end

def run_smoke_tests(logger)
  smoke_test_cmd = "-n run errand smoke-tests"
  exec_cmd_on_ops_mgr(smoke_test_cmd, logger)
  logger.info("BOSH:SmokeTest:Complete")
end

def bosh_login(username, password, logger)
  exec_cmd_on_ops_mgr("echo '#!/bin/bash' > /home/ubuntu/bosh_login.sh", logger, false)
  exec_cmd_on_ops_mgr("echo 'BUNDLE_GEMFILE=/home/tempest-web/tempest/web/vendor/bosh/Gemfile bundle exec bosh login >/dev/null <<-END' >> /home/ubuntu/bosh_login.sh", logger, false)
  exec_cmd_on_ops_mgr("echo '#{username}' >> /home/ubuntu/bosh_login.sh", logger, false)
  exec_cmd_on_ops_mgr("echo '#{password}' >> /home/ubuntu/bosh_login.sh", logger, false)
  exec_cmd_on_ops_mgr("echo 'END' >> /home/ubuntu/bosh_login.sh", logger, false)
  exec_cmd_on_ops_mgr("chmod +x /home/ubuntu/bosh_login.sh", logger, false)
  exec_cmd_on_ops_mgr("/home/ubuntu/bosh_login.sh", logger, false)
  logger.info("BOSHDirector:Login:Complete")
  exec_cmd_on_ops_mgr("rm -f /home/ubuntu/bosh_login.sh", logger, false)
  logger.info("BOSHDirector:CleanUp:Complete")
end

def go_to_sleep(command = nil, log_level = nil)
  if command.nil?
    raise "ARGMissing::start/stop Usage: ./aws_manager.rb <start/stop>"
  end

  logger = Logger.new(STDOUT)

  if ENV['AWS_ACCESS_KEY_ID'].nil? or ENV['AWS_SECRET_ACCESS_KEY'].nil? or ENV['REGION'].nil? or ENV['DEPLOYMENT_NAME'].nil? or ENV['OPS_MANAGER_HOSTNAME'].nil? or ENV['OPS_MANAGER_KEY_NAME'].nil?
    p "AWS:#{ENV['AWS_ACCESS_KEY_ID']}:#{ENV['AWS_SECRET_ACCESS_KEY']}:#{ENV['REGION']}:#{ENV['DEPLOYMENT_NAME']}"
    p "OPS:#{ENV['OPS_MANAGER_HOSTNAME']}:#{ENV['OPS_MANAGER_KEY_PATH']}"
    raise "ERROR:MissingConfig:AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY/REGION/DEPLOYMENT_NAME"
  else
    access_key_id = ENV['AWS_ACCESS_KEY_ID']
    secret_access_key =  ENV['AWS_SECRET_ACCESS_KEY']
    region = ENV['REGION']
    deployment_name = ENV['DEPLOYMENT_NAME']
    sequence_data = YAML.load_file( "#{ENV['PWD']}/aws-frugal-repo/deploy_pcf/aws/aws-frugal/scripts/start_stop_sequence.yml")
  end

  if !log_level.nil? && (log_level.downcase) == 'info'
    logger.level = Logger::INFO
  end

  ec2_client = AWS::EC2.new(region: region, access_key_id: access_key_id, secret_key_id: secret_access_key)
  case command
  when 'start'
    target_bosh_director(logger)
    set_bosh_deployment(deployment_name, logger)
    start_seq = list_sequence('start', deployment_name, sequence_data, ec2_client, logger)
    start_instances(start_seq, ENV['DEPLOYMENT_NAME'], logger)
  when 'stop'
    target_bosh_director(logger)
    set_bosh_deployment(deployment_name, logger)
    stop_seq = list_sequence('stop', deployment_name, sequence_data, ec2_client, logger)
    stop_instances(stop_seq, ENV['DEPLOYMENT_NAME'], logger)
  when 'smoke_tests'
    target_bosh_director(logger)
    set_bosh_deployment(deployment_name, logger)
    run_smoke_tests(logger)
  when 'clist'
    start_seq = list_sequence('start', deployment_name, sequence_data, ec2_client, logger)
    stop_seq = list_sequence('stop', deployment_name, sequence_data, ec2_client, logger)
    logger.info("StartSequence:#{start_seq}")
    logger.info("StopSequence:#{stop_seq}")
  when 'exec'
    exec_cmd_on_ops_mgr(log_level, logger)
  when 'target_bosh'
    target_bosh_director(logger)
  else
    raise "ERROR:WrongArgument:: Usage: ./aws_manager.rb <start/stop>"
  end
end

if __FILE__ == $PROGRAM_NAME
  go_to_sleep(*ARGV)
end
