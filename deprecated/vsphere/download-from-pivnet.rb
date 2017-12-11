#!/usr/bin/env ruby

require 'httparty'
require 'optparse'
require 'pdf-reader'

def get_latest_product_version(product_name, version='')
  url = "#{@pivnet_api}/#{product_name}/releases"
  product_releases = make_get_request(url).parsed_response
  product_versions = product_releases['releases'].map {|release| release['version']}

  product_versions.keep_if { |a| a=~ /^[0-9].[0-9].*$/}

  product_versions = product_versions.sort_by do |x|
    x.split(".").map {|i| i.to_i}
  end

  product_versions.reverse!

  if version == 'help'
    return product_versions
  end

  if version == 'latest-stable'
    product_versions.keep_if { |a| a=~ /^[0-9].[0-9](.\d+)*$/}
  else
    if version.downcase.include? 'latest-stable'
      product_versions.keep_if { |a| a=~ /^#{version.gsub('latest-stable', '')}(.\d+)*$/}
    else
      product_versions.keep_if { |a| a=~ /^#{version.gsub('latest', '')}.*$/}
    end
  end
  product_versions.first
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

def download(product, version=nil, cloudformation=nil, iaas='vsphere')
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
    product_file_name = product_files['product_files'].select { |product_files| product_files['name'].downcase.include? iaas}.first['aws_object_key'].split('/').last
    product_file_id = product_files['product_files'].select { |product_files| product_files['name'].downcase.include? iaas}.first['id']
  elsif product == 'elastic-runtime'
    if cloudformation
      download_object = product_files['product_files'].select { |product| product['name'].downcase.include? "cloudformation"}.first
    else
      download_object = product_files['product_files'].select {|product| product['name'] == 'PCF Elastic Runtime'}.first
    end
    product_file_name = download_object['aws_object_key'].split('/').last
    product_file_id = download_object['id']
  end

  download_link = "#{releases_url}/#{release['id']}/product_files/#{product_file_id}/download"
  make_post_request("#{releases_url}/#{release['id']}/eula_acceptance")
  wget_from_pivnet(download_link, product_file_name)
  generate_ami_yaml(product_file_name) if iaas == 'aws'
end

def generate_ami_yaml(path_to_pdf)
  pdf_content = PDF::Reader.new(path_to_pdf).pages.first.text
  pdf_content = pdf_content.split("\n").select {|lines| lines.include? "•" }
  pdf_content.map! { |x|  x.gsub(/^\s*|•|\*|\ \(.*\)/,'') }
  hash = {}
  pdf_content.each { |ami| hash[ami.split(':').first.strip] = ami.split(':').last.strip }
  File.open('amis.yml', 'w') {|f| f.write hash.to_yaml }
  puts "Finished generating amis.yml"
end



raise "Please set the env variable 'PIVNET_TOKEN' to be your network.pivotal.io token" if ENV['PIVNET_TOKEN'].nil?
@pivnet_api = 'https://network.pivotal.io/api/v2/products'
@pivnet_token = ENV.fetch('PIVNET_TOKEN')



options = {}
OptionParser.new do |opts|
  opts.banner = "Usage:\n\n --ops-manager <om-version> --elastic-runtime <ert-version> --cloud-formation --iaas <iaas>\n\n --ops-manager latest --elastic-runtime latest\n\n export OPSMGR_VERSION=<version or 'latest'> ERT_VERSION=<version or 'latest'> --ops-manager --elastic-runtime\n\n --elastic-runtime <ert-version> --cloud-formation #downloads the cloud formation json for that ERT version\n\n --ops-manager <om-version> --iaas <iaas> #downloads the ops manager for specified IaaS"
  opts.on('-o', '--ops-manager [OM]') do |ops_manager|
    if (ops_manager && ops_manager.downcase.include?('latest'))
      options[:ops_manager] = get_latest_product_version('ops-manager', ops_manager)
    elsif ops_manager
      options[:ops_manager] = ops_manager
    elsif (ENV['OPSMGR_VERSION'] && ENV['OPSMGR_VERSION'].downcase.include?('latest'))
      options[:ops_manager] = get_latest_product_version('ops-manager', ENV['OPSMGR_VERSION'])
    elsif ENV['OPSMGR_VERSION']
      options[:ops_manager] = ENV['OPSMGR_VERSION']
    end
  end
  opts.on('-i', '--iaas [iaas]') do |iaas|
    options[:iaas] = iaas.downcase
  end
  opts.on('-e', '--elastic-runtime [ert]') do |elastic_runtime|
    if (elastic_runtime && elastic_runtime.downcase.include?('latest'))
      options[:elastic_runtime] = get_latest_product_version('elastic-runtime', elastic_runtime)
    elsif elastic_runtime
      options[:elastic_runtime] = elastic_runtime
    elsif (ENV['ERT_VERSION'] && ENV['ERT_VERSION'].downcase.include?('latest'))
      options[:elastic_runtime] = get_latest_product_version('elastic-runtime', ENV['ERT_VERSION'])
    elsif ENV['ERT_VERSION']
      options[:elastic_runtime] = ENV['ERT_VERSION']
    end
  end
  opts.on('-c', '--cloud-formation') do |cloud_formation|
    options[:cloud_formation] = true if (cloud_formation)
  end
  opts.on('-p', '--print-latest [PRODUCT]') do |product|
    options[:print] = true
    if product.downcase.include? 'ops-manager'
      version = product.gsub!('ops-manager', '')
      puts get_latest_product_version('ops-manager', version)
    elsif product.downcase.include? 'elastic-runtime'
      version = product.gsub!('elastic-runtime', '')
      puts get_latest_product_version('elastic-runtime', version)
    else
      version = product
      puts "opsmanager version: #{get_latest_product_version('ops-manager', version)}"
      puts "elastic runtime version: #{get_latest_product_version('elastic-runtime', version)}"
    end
  end
  opts.on('-h', '--help [ERT]') do |help|
    options[:help] = help
    options[:help] ||= 'help'
  end
  @opts = opts
end.parse!


if options[:help] || options.empty?
  puts @opts
  puts ''
  puts "Available Ops Manager versions:"
  p get_latest_product_version('ops-manager', 'help')

  puts "\nAvailable Elastic Runtime versions:"
  p get_latest_product_version('elastic-runtime', 'help')
  exit
end


if options.key?(:ops_manager)
  if options[:ops_manager].nil?
    puts 'Could not find specified version of Ops Manager.'
  else
    options[:iaas] = 'vsphere' if options[:iaas].nil?
    if ['vsphere', 'aws', 'openstack'].include?(options[:iaas].downcase)
      puts "Downloading: Ops Manager - #{options[:ops_manager]} for Iaas - #{options[:iaas]}"
      download('ops-manager', options[:ops_manager], nil, options[:iaas])
    else
      puts "IaaS: #{options[:iaas]} is not supported by this script"
    end
  end
end
if options.key?(:elastic_runtime)
  if options[:elastic_runtime].nil?
    puts 'Could not find specified version of Elastic Runtime'
  else
    if options[:cloud_formation]
      puts "Downloading: Cloud Formation for ERT - #{options[:elastic_runtime]}"
      download('elastic-runtime', options[:elastic_runtime], options[:cloud_formation])
    else
      puts "Downloading: Elastic Runtime - #{options[:elastic_runtime]}"
      download('elastic-runtime', options[:elastic_runtime])
    end
  end
end
