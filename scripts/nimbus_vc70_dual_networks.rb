$testbed = Proc.new do
  {
    "name" => "testbed-test",
    "version" => 3,
     "network" => [
      {
        "name" => "net.0",
        "enableDhcp" => true
      }],

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
        "fullClone" => true,
        "disks" => [ 10 * 1000 * oneGB ], # 10 TB Diska
        "nics" => 2,
        "networks" => ["public", "nsx::net.0"]
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
        ],
        "nics" => 2,
        "networks" => ["public", "nsx::net.0"]
      }
    ],

    "beforePostBoot" => Proc.new do |runId, testbedSpec, vmList, catApi, logDir|
    end,
    "postBoot" => Proc.new do |runId, testbedSpec, vmList, catApi, logDir|
    end
  }
end
