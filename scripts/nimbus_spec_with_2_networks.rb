oneGB = 1 * 1000 * 1000 # in KB
 
$testbed = Proc.new do
  {
    'network' => [
      {'name' => 'net.1', "enableDhcp" => true},
    ],
    "name" => "testbed-test",
    "version" => 3,
    "esx" => (0..0).map do | idx |
      {
        "name" => "esx.#{idx}",
        "vc" => "vc.0",
        "customBuild" => "ob-15843807",
        "dc" => "vcqaDC",
        "clusterName" => "cluster0",
        "style" => "fullInstall",
        "cpus" => 32, # 32 vCPUs
        "memory" => 98000, # 98GB memory
        "disks" => [ 1000 * oneGB, 1000 * oneGB ],
        "guestOSlist" => [         
          {
            "vmName" => "centos-vm.#{idx}",
            "ovfuri" => NimbusUtils.get_absolute_ovf("CentOS6_x64_2GB/CentOS6_x64_2GB.ovf")
          },
        ]
      }
    end,
 
    "vcs" => [
      {
        "name" => "vc.0",
        "type" => "vcva",
        "customBuild" => "ob-15952498",
        "dcName" => ["vcqaDC"],
        "enableDrs" => true,
        "clusters" => [
          {
            "name" => "cluster0",
            "dc" => "vcqaDC"
          }
        ]
      }
    ],
    

    "beforePostBoot" => Proc.new do |runId, testbedSpec, vmList, catApi, logDir|
    end,
    "postBoot" => Proc.new do |runId, testbedSpec, vmList, catApi, logDir|
    end
  }
end
