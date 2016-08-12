##Deploy PCF

###Overview:

This folder is a collection of scripts and Concourse pipeline that can help you easily deploy Pivotal Cloud Foundry.

* `deploy-pcf.yml` - This is a Concourse CI pipeline that uses the two scripts listed below to automate a PCF installation.
* `deploy_pcf.rb` - This script can be used to deploy Ops Manager and ERT using the pivotal-cf/p-runtime gem
* `download-from-pivnet.rb` - This script can be used to download Ops Manager and ERT using the Pivotal Network API

###deploy-pcf.yml
####Prerequisites:
- Concourse deployment that has access to environments.toolsmiths.cf-app.com
- An environment signed out on environments.toolsmiths.cf-app.com
- Github key that has access to pivotal-cf/p-runtime
- Pivnet API token

####Usage:
- Edit `deploy-pcf.yml` and configure the following values found at the top of the file:
```
opsmgr_version: &opsmgr_version 1.7.7
ert_version: &ert_version 1.7.6
environment_name: &env_name stormwind
env_app_url: &env_app_url environments.toolsmiths.cf-app.com
pivnet_token: &pivnet_token {{pivnet-token}}
worker_tag: &worker_tag [vsphere]
github_key: &github_key {{github-key}}
```
- Use the yml to set a pipeline on your concourse deployment.

####Notes:
- There is Concourse (v1.2) bug where sometimes the artifacts will not get pass between the tasks properly. This is a known issue and will be fixed.
- We've also noticed that sometimes wget will fail with a 403 error when trying to download from pivnet. 
- You can specify 'latest' for opsmgr_version and ert_version. When specifying 'latest' - make sure the products are compatible.


### deploy_pcf.rb
####Prerequisites:

- [p-runtime](https://github.com/pivotal-cf/p-runtime) located in the directory ~/workspace/p-runtime
- Deployment manifest
- OpsManager OVA (from network.pivotal.io)
- Optional: Elastic Runtime Tile (from network.pivotal.io)

####Usage:

- run `./deploy_pcf.rb` to see usage notes

```
Usage: deploy_pcf.rb [options]
    -d, --dry-run
    -D [DIR],
        --environment-directory
    -N, --environment-name [NAME]
    -O, --ops-manager [PATH]
    -V [VERSION],
        --ops-manager-version
    -E, --elastic-runtime [PATH]
    -W [VERSION],
        --elastic-runtime-version
    -S, --stemcell [PATH]
    -H, --headless
    -I, --interactive
    -i, --iaas
    -C, --commands [CMDS]
    -h, --help
```

- `-d` This option will print out the commands to be issued to p-runtime
- `-D` This specifies the directory where your deployment manifest is. It defaults to `~/`.
- `-N` This is the name of the environment you wish to deploy. It should also be the name of your deployment manifest. 
- `-O` This is the full path to the Ops Manager OVA you wish to deploy.
- `-V` This is the version of Ops Manager you wish to deploy. If -O <path to ova> is specified, the script will determine the version from the file name.
- `-E` This is the full path to the elastic runtime tile you wish to deploy.
- `-W` This is the version of elastic runtime you wish to deploy. If -E <path to .pivotal> is specified, the script will determine the version from the file name.
- `-S` This is the full path to the stemcell you wish to use. If -E and -i are both set, the script will download the correct stemcell for you.
- `-H` This option is used to run on a headless machine.
- `-I` This option will let you select which commands you wish to run. Helpful if you do not wish to run all the commands
- `-i` This option allows you to specify your iaas. This currently defaults to 'vsphere'
- `-C` This option will let you specify the commands you want to run in a comma separated string. i.e. -C opsmgr:install,opsmgr:configure
- `-h` This shows the usage information.

####Example:

```
→ ./deploy_pcf.rb -D ~/environments/config/ -N trackseven -O ~/Downloads/pcf-vsphere-1.6.6.0.ova -V 1.6 -E ~/Downloads/cf-1.6.10.pivotal -W 1.6 -I
Do you want to run: (y/n)
  bundle exec rake opsmgr:destroy[trackseven]
y
  bundle exec rake opsmgr:install[trackseven,/Users/pivotal/Downloads/pcf-vsphere-1.6.6.0.ova]
y
  bundle exec rake opsmgr:add_first_user[trackseven,1.6]
y
  bundle exec rake opsmgr:microbosh:configure[trackseven,1.6]
y
  bundle exec rake opsmgr:trigger_install[trackseven,1.6,40]
y
  bundle exec rake opsmgr:product:upload_add[trackseven,1.6,/Users/pivotal/Downloads/cf-1.6.10.pivotal,cf]
y
  bundle exec rake ert:configure[trackseven,1.6,1.6]
y
  bundle exec rake opsmgr:trigger_install[trackseven,1.6,240]
y
Run the following?
bundle exec rake opsmgr:destroy[trackseven]
bundle exec rake opsmgr:install[trackseven,/Users/pivotal/Downloads/pcf-vsphere-1.6.6.0.ova]
bundle exec rake opsmgr:add_first_user[trackseven,1.6]
bundle exec rake opsmgr:microbosh:configure[trackseven,1.6]
bundle exec rake opsmgr:trigger_install[trackseven,1.6,40]
bundle exec rake opsmgr:product:upload_add[trackseven,1.6,/Users/pivotal/Downloads/cf-1.6.10.pivotal,cf]
bundle exec rake ert:configure[trackseven,1.6,1.6]
bundle exec rake opsmgr:trigger_install[trackseven,1.6,240]
yes
```

### download-from-pivnet.rb 
#### Prerequisites

```
export PIVNET_TOKEN=<YOUR PIVNET TOKEN>
```

#### Usage:

```
Usage:

 --ops-manager <om-version> --elastic-runtime <ert-version>

 --ops-manager latest --elastic-runtime latest

 export OPSMGR_VERSION=<version or 'latest'> ERT_VERSION=<version or 'latest'> --ops-manager --elastic-runtime

    -o, --ops-manager [OM]
    -e, --elastic-runtime [ERT]
    -p, --print-latest [PRODUCT]
    -h, --help [ERT]

Available Ops Manager versions:
["1.7RC", "1.7.7", "1.7.6", "1.7.5.0", "1.7.4.0", "1.7.3.0", "1.7.2.0", "1.7.1.0", "1.7.0.0"]

Available Elastic Runtime versions:
["1.7.6", "1.7.5", "1.7.4", "1.7.3", "1.7.2", "1.7.1", "1.7.0 RC4", "1.7.0 RC3", "1.7.0", "1.6.9"]
```
#### Notes:

* The Ops Manager and Elastic Runtime versions need to be exact if you wish to download a specific version. You can get the exact version number from the 'help' output
  * If you want the latest version you can specify 'latest'
  * If you want the latest stable version (it will ignore RC and alphas), use 'latest-stable'
  * You can also prepend a version to get the latest of that version, '1.7latest', '1.7latest-stable'
* '-p' - to print the latest product version, please specify the product name as 'ops-manager' or 'elastic-runtime'
  * you can also specify 'ops-managerlatest', 'ops-manager1.6latest', 'ops-manager1.7latest-stable'
