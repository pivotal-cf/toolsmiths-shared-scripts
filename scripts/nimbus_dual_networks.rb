{
  'name' => 'ntf-testbed-multi-networks',
  'network' => [
    {
      'name' => 'net.0'
    }
  ],
  'genericVM' => [
    {
      'type' => 'worker-template',
      'nics' => 2,
      'networks' => ['public', 'nsx::net.0']
    },
    {
      'type' => 'worker-template',
      'nics' => 2,
      'networks' => ['nsx::net.0']
    }
  ]
}
