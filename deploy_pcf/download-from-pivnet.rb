#!/usr/bin/env ruby

require 'httparty'
require 'optparse'

def get_latest_product_version(product_name)
  url = "#{@pivnet_api}/#{product_name}/releases"
  product_releases = make_get_request(url).parsed_response
  product_versions = product_releases['releases'].map {|release| release['version']}
  product_versions.keep_if { |a| a=~ /^[0-9].[0-9].*$/}
  product_versions.sort! {|a,b| b <=> a }.first
end


def make_get_request(endpoint)
  response = HTTParty.get(endpoint,
              headers: {
                'Accept' => "application/json",
                'Content-Type' => "application/json",
                'Authorization' => "Token #{@pivnet_token}",
              }
    )
  unless response.success?
    raise "Error making a GET request to #{endpoint}"
  end
  response
end

def make_post_request(endpoint)
  response = HTTParty.post(endpoint,
              # :debug_output => $stdout,
              headers: {
                'Accept' => "application/json",
                'Content-Type' => "application/json",
                'Authorization' => "Token #{@pivnet_token}",
              }
    )
  unless response.success?
    raise "Error making a POST request to #{endpoint}"
  end
  response
end

def wget_from_pivnet(endpoint, filename, path=nil)
  if path
    Dir.mkdir path
    actual_path = "#{path}/#{filename}"
  else
    actual_path = filename
  end
  `wget -O #{actual_path} --post-data="" --header="Authorization: Token #{@pivnet_token}" #{endpoint}`
  if $?.to_i != 0
    puts "wget failed."
    exit 1
  end

end

def download(product, version=nil)
  releases_url = "#{@pivnet_api}/#{product}/releases"
  product_releases = make_get_request(releases_url).parsed_response
  if !version.empty?
    release = product_releases['releases'].select { |release| release['version'] == version }.first
  else
    release = product_releases['releases'].first
  end

  if !release
    puts "Cannot find #{version} for #{product}. See available versions below:\n"
    product_releases['releases'].each {|release| puts release['version']}
    exit
  end
  product_files = make_get_request("#{releases_url}/#{release['id']}/product_files").parsed_response

  if product == 'ops-manager'
    product_file_name = product_files['product_files'].select { |product_files| product_files['name'].include? 'vSphere'}.first['aws_object_key'].split('/').last
    product_file_id = product_files['product_files'].select { |product_files| product_files['name'].include? 'vSphere'}.first['id']
  elsif product == 'elastic-runtime'
    download_object = product_files['product_files'].select {|product| product['name'] == 'PCF Elastic Runtime'}.first
    product_file_name = download_object['aws_object_key'].split('/').last
    product_file_id = download_object['id']
  end

  download_link = "#{releases_url}/#{release['id']}/product_files/#{product_file_id}/download"
  make_post_request("#{releases_url}/#{release['id']}/eula_acceptance")
  wget_from_pivnet(download_link, product_file_name)
end

raise "Please set the env variable 'PIVNET_TOKEN' to be your network.pivotal.io token" if ENV['PIVNET_TOKEN'].nil?
@pivnet_api = 'https://network.pivotal.io/api/v2/products'
@pivnet_token = ENV.fetch('PIVNET_TOKEN')

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage:\n\n --ops-manager <om-version> --elastic-runtime <ert-version>\n\n --ops-manager latest --elastic-runtime latest\n\n export OPSMGR_VERSION=<version or 'latest'> ERT_VERSION=<version or 'latest'> --ops-manager --elastic-runtime\n\n"
  opts.on('-o', '--ops-manager [OM]') do |ops_manager|
    if ops_manager == 'latest'
      options[:ops_manager] = get_latest_product_version('ops-manager')
    elsif ops_manager
      options[:ops_manager] = ops_manager
    elsif ENV['OPSMGR_VERSION'] && ENV['OPSMGR_VERSION'] == 'latest'
      options[:ops_manager] = get_latest_product_version('ops-manager')
    elsif ENV['OPSMGR_VERSION']
      options[:ops_manager] = ENV['OPSMGR_VERSION']
    end
  end
  opts.on('-e', '--elastic-runtime [ERT]') do |elastic_runtime|
    if elastic_runtime == 'latest'
      options[:elastic_runtime] = get_latest_product_version('elastic-runtime')
    elsif elastic_runtime
      options[:elastic_runtime] = elastic_runtime
    elsif ENV['ERT_VERSION'] && ENV['ERT_VERSION'] == 'latest'
      options[:elastic_runtime] = get_latest_product_version('elastic-runtime')
    elsif ENV['ERT_VERSION']
      options[:elastic_runtime] = ENV['ERT_VERSION']
    end
  end
  opts.on('-p', '--print-latest [PRODUCT]') do |product|
    case product
    when 'ops-manager'
      puts get_latest_product_version('ops-manager')
    when 'elastic-runtime'
      puts get_latest_product_version('elastic-runtime')
    else
      puts "opsmanager version: #{get_latest_product_version('ops-manager')}"
      puts "elastic runtime version: #{get_latest_product_version('elastic-runtime')}"
    end
  end
  opts.on('-h', '--help [ERT]') do |help|
    options[:help] = help
    puts opts
    options[:help] ||= 'help'
  end
end.parse!


if options[:help]
  ops_manager_url = "#{@pivnet_api}/ops-manager/releases"
  ops_manager_releases = make_get_request(ops_manager_url).parsed_response
  puts "Available Ops Manager versions:"
  ops_manager_versions = ops_manager_releases['releases'].map {|release| release['version']}
  p ops_manager_versions.sort! {|a,b| b <=> a }

  elastic_runtime_url = "#{@pivnet_api}/elastic-runtime/releases"
  elastic_runtime_releases = make_get_request(elastic_runtime_url).parsed_response
  puts "\nAvailable Elastic Runtime versions:"
  elastic_runtime_versions = elastic_runtime_releases['releases'].map {|release| release['version']}
  p elastic_runtime_versions.sort! {|a,b| b <=> a }
  exit
end


options.each {|product,version|puts "Downloading: #{product} - #{version}\n" }
download('ops-manager', options[:ops_manager]) if options[:ops_manager]
download('elastic-runtime', options[:elastic_runtime]) if options[:elastic_runtime]
