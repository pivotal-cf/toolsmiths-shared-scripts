# aws-frugal

**Please Note: The London Services team has developed an IAAS-agnostic set of tooling at: https://github.com/pivotal-cf-experimental/pcf_pause**  

**I believe this will be a better solution moving forward and recommend you check it out.**

===
Tools to stop PCF instances on AWS during off-hours and automatically start all instance and run smoke tests before office starts.

### Supported PCF version:
* 1.7 and above because of UAA dependencies in scripts for OPS Manager authentication.

===
## Overview

This Concourse pipeline is used to stop/start jobs in your PCF deployment on AWS. There is cron scheduler in pipeline YAML which can be modified as per your requirements.

#### How the pipeline gona save money:

* The pipeline will trigger stop sequence commands to BOSH as per cron schedule. It will use OPS Manager VM as jumpbox and save job-id in your git repo for next tasks.
* The pipeline will trigger start sequence commands to BOSH as per the cron schedule and will use `instance_data.yml` saved in stop job
* Send slack notifications to your channel:
	* when all jobs are stopped successfull
	* when all jobs are started successfull and smoke tests are green
	* when bosh targeting failed
	* when start/stop failed.
	

* This pipeline is separated into 2 pipeline groups:

	* stop-instances: to stop all jobs
	* start-instances: to start all jobs and run smoke-tests errand on your environment.

**NOTE:** Stop/Start squence are specified in [PCF Docs.](https://docs.pivotal.io/pivotalcf/1-7/customizing/start-stop-vms.html)

#### Prerequisites:

* Github repo for storing OPS Manager SSH Key and instance job-id data
* cron-resouce installed in your concourse (name it `cron` or change cron resource name in `aws-frugal.yml`): https://github.com/pivotal-cf-experimental/cron-resource

	**NOTE**: make sure your start/stop jobs are not running on weekends.

* BOSH CLI installed on OPS Manager (by default its installed in OPS Manager)


#### Usage:

Edit aws-frugal.yml in `toolsmiths-shared-scripts/deploy_pcf/aws/aws-frugal/pipeline` and configure the following values at the top of the file:
 
 	```
	#BOSH director default root cert path on OPS Manager
	bosh_director_cert_path: &bosh_director_cert_path "/var/tempest/workspaces/default/root_ca_certificate"

	github_key: &github_key <GITHUB-KEY>
	github_username: &github_username <GITHUB-USERNAME> #for github commits to store state
	github_email: &github_email <GITHUB-EMAIL>
	env_repo:  &env_repo <ENVIRONMENT-REPO-TO-STORE-INSTANCE-DATA> # git@github.com:<YOUR-ORG>/<YOUR-REPO>
	env_state_folder: &env_state_folder <ENVIRONMENT-FOLDER> # this is the path within your git repo to store instance_data
	ops_manager_key_name: &ops_manager_key_name <OPS-MANAGER-KEY-NAME> # this will be the ssh-key to login into your OPS Manager should be in your ENVIRONMENT-FOLDER

	# cron schedule: https://github.com/pivotal-cf-experimental/cron-resource
	morning_start_trigger: *morning_start_trigger "0 7 * * 1-5"  # ex: 7AM Monday-Friday
	evening_stop_trigger: *evening_stop_trigger "0 18 * * 1-5"  # ex: 6PM Monday-Friday
	trigger_time_zone: *trigger_time_zone "America/New_York"  # Locations: https://godoc.org/time#LoadLocation

	aws_access_key_id: &aws_access_key_id <AWS-ACCESS-KEY-ID>
	aws_secret_access_key: &aws_secret_access_key <AWS-SECRET-ACCESS-KEY>
	region: &aws_region <AWS-REGION>
	deployment_name: &deployment_name <PCF-DEPLOYMENT-NAME> # something like cf-partition-9965d7cc1758828b974f

	# ops manager info
	ops_manager_hostname: &ops_manager_hostname <OPS-MANAGER-HOSTNAME> # ex: pcf.polwol.cf-app.com
	ops_manager_username: &ops_manager_username <OPS-MANAGER-USERNAME>
	ops_manager_password: &ops_manager_password <OPS-MANAGER-PASSWORD>

	# slack notification info
	# NOTE: if you want to remove slack-notificaiton, remove all slack-notification modules from tasks
	slack_url: &slack_url <SLACK-URL> #ex:  https://hooks.slack.com/services/T024LQKAS/B0D78J0QP/zUD
	slack_channel: &slack_channel <SLACK-CHANNEL> # ex: "#toolsmiths"
	slack_username: &slack_username <SLACK-USERNAME> # username used for slack commnets
	slack_icon_url: &slack_icon_url "https://avatars1.githubusercontent.com/u/5589368?v=3&s=400"
	slack_start_failed_msg: &slack_start_failed_msg "Start:AllInstances:Failed, check pipeline for details: aws-frugal"
	slack_stop_failed_msg: &slack_stop_failed_msg "Stop:AllInstances:Failed, check pipeline for details: aws-frugal"

 	```	

#### Jobs:

##### stop-instances
* Connects to AWS Account and create intance map from deployment tags as stop squence.
* Authenticate with OPS Manager --> Get BOSH manifest --> Extract BOSH Director credentials
* Send BOSH target command to OPS Manager VM
* Send Stop Instance commands to BOSH in sequence
* Save instance job-ids in instance_data.yml file and commit it to your environment repo
* Send slack notification to team channel with status.


##### start-instances
* Use instace job-ids data file (instance_data.yml) to create start sequence
* Authenticate with OPS Manager --> Get BOSH manifest --> Extract BOSH Director credentials.
* Send BOSH target command to OPS Manager VM
* Send Start Instance commands to BOSH in sequence
* Send smoke test run command to BOSH once the start sequence is complete
* Send slack notification to team channel with status.
