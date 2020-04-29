{
"name" => "dual-network-testbed"
"network" => [
   {
     "name" => "net.0",
     "enableDhcp" => true
   }
]
 
"genericVm" => [
   {
      "name" => "worker.0",
      "type" => "worker-template",
      "nics" => 2,
      "networks" => ["public", "nsx::net.0"]
   },
   {
      "name" => "worker.1",
      "type" => "worker-template",
      "nics" => 2,
      "networks" => ["nsx::net.0"]
   }
]
}
