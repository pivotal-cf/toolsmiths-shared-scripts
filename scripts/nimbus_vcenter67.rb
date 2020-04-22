oneGB = 1 * 1000 * 1000 # in KB
 
$testbed = Proc.new do
  {
    "name" => "testbed-test",
    "version" => 3,
    "esx" => (0..1).map do | idx |
      {
        "name" => "esx.#{idx}",
        "vc" => "vc.0",
        "customBuild" => "ob-15817962",
        "dc" => "vcqaDC",
        "clusterName" => "cluster0",
        "style" => "fullInstall",
        "cpus" => 32, # of vCPUs
        "memory" => 98000, # 98GB memory
        "disks" => [ 1000 * oneGB, 1000 * oneGB ],
        "nicType" => ["vmxnet3"],
        "network" => ["public"],
        "guestOSlist" => [         
          {
            "vmName" => "centos-vm.#{idx}",
            "ovfuri" => NimbusUtils.get_absolute_ovf("CentOS6_x64_2GB/CentOS6_x64_2GB.ovf")
          }
        ]
      }
    end,
 
    "vcs" => [
      {
        "name" => "vc.0",
        "type" => "vcva",
        "customBuild" => "ob-15843809",
        "dcName" => ["vcqaDC"],
        "clusters" => [
          {
            "name" => "cluster0",
            "dc" => "vcqaDC",
            "enableDrs" => true
          }
        ],
        "nicType" => ["vmxnet3"],
        "network" => ["public"],
      }
    ],
 
    "beforePostBoot" => Proc.new do |runId, testbedSpec, vmList, catApi, logDir|
    end,
    "postBoot" => Proc.new do |runId, testbedSpec, vmList, catApi, logDir|
    end
  }
end
