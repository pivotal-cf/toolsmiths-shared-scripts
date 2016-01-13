##Deploy PCF

####Overview:

This script can compose and run a series of commands that can be issued to the p-runtime gem to deploy PCF


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
    -h, --help
```

- `-d` This option will print out the commands to be issued to p-runtime
- `-D` This specifies the directory where your deployment manifest is. It defaults to `~/workspace/deployments-toolsmiths/vcenter/environments/config`
- `-N` This is the name of the environment you wish to deploy. It should also be the name of your deployment manifest. 
- `-O` This is the full path to the Ops Manager OVA you wish to deploy.
- `-V` This is the version of Ops Manager you wish to deploy.
- `-E` This is the full path to the elastic runtime tile you wish to deploy.
- `-W` This is the version of elastic runtime you wish to deploy.
- `-S` This is the full path to the stemcell you wish to use. This is often unnecessary.
- `-H` This option is used to run on a headless machine.
- `-I` This option will let you select which commands you wish to run. Helpful if you do not wish to run all the commands
- `-h` This shows the usage information.

####Example:

```
→ ./deploy_pcf.rb -D ~/workspace/deployments-toolsmiths/vcenter/environments/config/ -N trackseven -O ~/Downloads/pcf-vsphere-1.6.6.0.ova -V 1.6 -E ~/Downloads/cf-1.6.10.pivotal -W 1.6 -I
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
