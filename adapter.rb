# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'rubygems'
require 'bundler/setup'
require 'json'
require 'nokogiri'

require 'myst'

include Myst::Providers::VCloud

class NetworkTask
  attr_reader :token, :name, :href, :owner, :status, :progress, :xml, :http

  def initialize(args)
    @token = args[:token]
    @http = args[:http]
    load args[:xml]
  end

  def load(xml)
    @xml = Nokogiri::XML(xml)
    @href = @xml.at_xpath('/xmlns:Task').get_attribute('href')
    @name = @xml.at_xpath('/xmlns:Task').get_attribute('operationName')
    @status = @xml.at_xpath('/xmlns:Task').get_attribute('status')

    if @owner == @xml.at_xpath('/xmlns:Task/xmlns:Owner')
      @owner = @xml.at_xpath('/xmlns:Task/xmlns:Owner').get_attribute('href')
    end

    if @xml.at_xpath('/xmlns:Task/xmlns:Progress')
      @progress = @xml.at_xpath('/xmlns:Task/xmlns:Progress').content
    else
      @progress = nil
    end
  end

  def update
    request = Net::HTTP::Get.new(@href)
    request['accept'] = 'application/*+xml;version=5.5'
    request['x-vcloud-authorization'] = token
    res = http.request(request)
    load res.body
  end

  def wait_for_task
    while status == 'running'
      sleep 2
      update
    end
    return false if status == 'error'
    true
  end
end

def delete_network(data)
  values = data.values_at(:datacenter_name, :client_name, :name).compact
  return false unless data[:router_type] == 'vcloud' && values.length == 3

  credentials = data[:datacenter_username].split('@')
  provider = Provider.new(endpoint:     data[:vcloud_url],
                          organisation: credentials.last,
                          username:     credentials.first,
                          password:     data[:datacenter_password])
  datacenter      = provider.datacenter(data[:datacenter_name])
  network         = datacenter.private_network(data[:name])

  # Filthy hack, because the vcloud sdk doesn't let us delete a network as a non-admin
  return 'network.delete.vcloud.done' if network.network.nil?
  network_href = network.network.getReference.getHref
  url = URI.parse(network_href.gsub(/network/, 'admin/network'))
  req = Net::HTTP::Delete.new(url.path)
  req['x-vcloud-authorization'] = provider.client.vcloud_token
  req['Accept'] = 'application/*+xml;version=5.1'

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  res = http.start { |h| h.request(req) }
  fail res.message if res.code != '202'

  # Wait for the delete to finish
  task = NetworkTask.new(xml: res.body, http: http, token: provider.client.vcloud_token)
  if task.wait_for_task
    'network.delete.vcloud.done'
  else
    'network.delete.vcloud.error'
  end
rescue => e
  puts e
  puts e.backtrace
  'network.delete.vcloud.error'
end

unless defined? @@test
  @data       = { id: SecureRandom.uuid, type: ARGV[0] }
  @data.merge! JSON.parse(ARGV[1], symbolize_names: true)
  original_stdout = $stdout
  $stdout = StringIO.new
  begin
    @data[:type] = delete_network(@data)
    if @data[:type].include? 'error'
      @data['error'] = { code: 0, message: $stdout.string.to_s }
    end
  ensure
    $stdout = original_stdout
  end

  puts @data.to_json
end
