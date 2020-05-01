#command to run: /mts/git/bin/nimbus-testbeddeploy --testbedSpecRubyFile https://raw.githubusercontent.com/pivotal-cf/toolsmiths-shared-scripts/master/scripts/dual-network.rb --runName dual-network-claas-centos1 --context general:nsx
$testbed = Proc.new do
{
   "name" => "dual-network-testbed",
   "version" => 3,
   "network" => [
      {
        "name" => "net.0",
        "enableDhcp" => true
      }
                ],
"genericVm" => [
   {
      "name" => "worker.0",
      "type" => "claas-centos",
      "nics" => 2,
      "networks" => ["public", "nsx::net.0"]
   },
   {
      "name" => "worker.1",
      "type" => "claas-centos",
      "nics" => 2,
      "networks" => ["nsx::net.0"]
   }
               ]
}
end
