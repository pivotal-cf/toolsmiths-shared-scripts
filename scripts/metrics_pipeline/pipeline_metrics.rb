#!/usr/bin/env ruby
#
require 'wavefront-sdk/credentials'
require 'wavefront-sdk/write'

metrics_source = ENV.fetch('METRICS_SOURCE')

wf = Wavefront::Write.new(
  Wavefront::Credentials.new.all,
  writer: :api,
  noauto: true,
)

wf.open

wf.write([{
  path: "toolsmiths.pipeline",
  value: ENV.fetch('PIPELINE_COMPLETE'),
  source: metrics_source,
  tags: {
    environment => ENV.fetch('ENV_NAME'),
    project => ENV.fetch('GCP_PROJECT_NAME'),
    pool => ENV.fetch('POOL_NAME')
  }
}])

wf.close
