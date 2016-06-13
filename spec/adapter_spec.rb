# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require_relative 'spec_helper'

describe 'vcloud_network_deleter_microservice' do
  let!(:provider) { double('provider', supu: 'supu') }

  before do
    allow_any_instance_of(Object).to receive(:sleep)
    require_relative '../adapter'
  end

  describe '#delete_network' do
    let!(:data)   do
      { router_name: 'adria-vse',
        router_type: 'vcloud',
        datacenter_username: 'acidre@r3labs-development',
        datacenter_name: 'r3-acidre',
        datacenter_password: 'ed7d0a9ffed74b2d3bc88198cbe7948c',
        client_name: 'r3labs-development',
        network_name: 'cdg-145-salt',
        network_start_address: '10.64.4.5',
        network_end_address: '10.64.4.250',
        network_netmask: '255.255.255.0',
        network_gateway: '10.64.4.1'

      }
    end
    let!(:datacenter)       { double('datacenter', private_network: private_network) }
    let!(:private_network)  { double('private_network', network: network) }
    let!(:network)          { double('network', delete: task, getReference: reference) }
    let!(:reference)        { double('reference', getHref: 'something/network/kk') }
    let!(:task)             { double('task', waitForTask: true) }
    let!(:client)           { double('client', vcloud_token: 'my_token') }
    let!(:response)         { double('response', code: '202', message: 'hi', body: 'hello') }

    before do
      allow_any_instance_of(Provider).to receive(:initialize).and_return(provider)
      allow_any_instance_of(Provider).to receive(:datacenter).and_return(datacenter)
      allow_any_instance_of(Provider).to receive(:client).and_return(client)
      allow_any_instance_of(Net::HTTP).to receive(:start).and_return(response)
      allow_any_instance_of(NetworkTask).to receive(:initialize).and_return(task)
      allow_any_instance_of(NetworkTask).to receive(:wait_for_task).and_return(true)
    end

    it 'delete a network on vcloud' do
      expect(delete_network(data)).to eq 'network.delete.vcloud.done'
    end
  end
end
