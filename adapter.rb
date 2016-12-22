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

def delete_network_request(url, token)
  5.times do
    req = Net::HTTP::Delete.new(url.path)
    req['x-vcloud-authorization'] = token
    req['Accept'] = 'application/*+xml;version=5.1'

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    res = http.start { |h| h.request(req) }

    return NetworkTask.new(xml: res.body, http: http, token: token) if res.code == '202'
   
    sleep 10
  end

  nil
end

def delete_network(data)
  usr = ENV['DT_USR'] || data[:datacenter_username]
  pwd = ENV['DT_PWD'] || data[:datacenter_password]
  credentials = usr.split('@')
  provider = Provider.new(endpoint:     data[:vcloud_url],
                          organisation: credentials.last,
                          username:     credentials.first,
                          password:     pwd)
  datacenter      = provider.datacenter(data[:datacenter_name])
  router          = datacenter.router(data[:router_name])
  network         = datacenter.private_network(data[:name])

  # wait for all prior tasks to complete
  router.wait_for_tasks

  # Filthy hack, because the vcloud sdk doesn't let us delete a network as a non-admin
  return 'network.delete.vcloud.done' if network.network.nil?
  network_href = network.network.getReference.getHref
  url = URI.parse(network_href.gsub(/network/, 'admin/network'))

  task = delete_network_request(url,  provider.client.vcloud_token)

  # Wait for the delete to finish
  if task.nil?
     'network.delete.vcloud.error'
  else
     task.wait_for_task
    'network.delete.vcloud.done'
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
