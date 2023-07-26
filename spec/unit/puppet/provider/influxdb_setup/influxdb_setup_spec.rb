# frozen_string_literal: true

require 'spec_helper'
require 'json'

ensure_module_defined('Puppet::Provider::InfluxdbSetup')
require 'puppet/provider/influxdb_setup/influxdb_setup'
require_relative '../../../../../lib/puppet_x/puppetlabs/influxdb/influxdb'
include PuppetX::Puppetlabs::PuppetlabsInfluxdb

RSpec.describe Puppet::Provider::InfluxdbSetup::InfluxdbSetup do
  subject(:provider) { described_class.new }

  let(:context) { instance_double('Puppet::ResourceApi::BaseContext', 'context') }

  let(:attrs) do
    {
      name: {
        type: 'String',
      },
      is_setup: {
        type: 'Boolean',
      },
      manage_setup: {
        type: 'Boolean',
      },
    }
  end

  describe '#get' do
    # rubocop:disable RSpec/SubjectStub
    context 'when not setup' do
      it 'processes resources' do
        allow(provider).to receive(:influx_get).with('/api/v2/setup').and_return([{ 'allowed' => true }])
        expect(provider.get(context)[0][:ensure]).to eq 'absent'
      end
    end

    context 'when setup' do
      it 'processes resources' do
        allow(provider).to receive(:influx_get).with('/api/v2/setup').and_return([{ 'allowed' => false }])
        expect(provider.get(context)[0][:ensure]).to eq 'present'
      end
    end

    context 'when using the system store' do
      it 'configures and uses the ssl context' do
        resources = [{
          use_ssl: true,
          use_system_store: true,
          host: 'foo.bar.com',
          port: 8086,
          token: RSpec::Puppet::Sensitive.new('puppetlabs'),
          bucket: 'puppet',
          org: 'puppetlabs',
          username: 'admin',
          password: RSpec::Puppet::Sensitive.new('puppetlabs'),
          token_file: '/tmp/foo',
          ensure: 'present'
        }]

        # canonicalize will set up the ssl_context and add it to the @client_options hash
        provider.canonicalize(context, resources)
        expect(provider.instance_variable_get('@client_options').key?(:ssl_context)).to eq true
      end

      it 'checks for a valid CA bundle' do
        resources = [{
          use_ssl: true,
          use_system_store: true,
          ca_bundle: '/not/a/file',
          host: 'foo.bar.com',
          port: 8086,
          token: RSpec::Puppet::Sensitive.new('puppetlabs'),
          bucket: 'puppet',
          org: 'puppetlabs',
          username: 'admin',
          password: RSpec::Puppet::Sensitive.new('puppetlabs'),
          token_file: '/tmp/foo',
          ensure: 'present'
        }]

        provider.canonicalize(context, resources)
        expect(instance_variable_get('@logs').any? { |log| log.message == 'No CA bundle found at /not/a/file' }).to eq true
      end
    end

    context 'when not using the system store' do
      it 'does not configure and uses the ssl context' do
        resources = [{
          use_ssl: true,
          use_system_store: false,
          host: 'foo.bar.com',
          port: 8086,
          token: RSpec::Puppet::Sensitive.new('puppetlabs'),
          bucket: 'puppet',
          org: 'puppetlabs',
          username: 'admin',
          password: RSpec::Puppet::Sensitive.new('puppetlabs'),
          token_file: '/tmp/foo',
          ensure: 'present'
        }]

        provider.canonicalize(context, resources)
        expect(provider.instance_variable_get('@client_options').key?(:ssl_context)).to eq false
      end
    end
  end

  describe '#create' do
    it 'creates resources' do
      provider.instance_variable_set('@use_ssl', true)
      provider.instance_variable_set('@host', 'foo.bar.com')
      provider.instance_variable_set('@port', 8086)
      provider.instance_variable_set('@token_file', '/root/.influxdb_token')
      provider.instance_variable_set('@token', RSpec::Puppet::Sensitive.new('puppetlabs'))

      should = {
        use_ssl: true,
        host: 'foo.bar.com',
        port: 8086,
        token: RSpec::Puppet::Sensitive.new('puppetlabs'),
        bucket: 'puppet',
        org: 'puppetlabs',
        username: 'admin',
        password: RSpec::Puppet::Sensitive.new('puppetlabs'),
        token_file: '/tmp/foo',
        ensure: 'present'
      }
      should_unwrapped = {
        bucket: 'puppet',
        org: 'puppetlabs',
        username: 'admin',
        password: 'puppetlabs'
      }

      allow(provider).to receive(:influx_post).with('/api/v2/setup', JSON.dump(should_unwrapped)).and_return({ 'auth' => { 'token' => 'token' } })

      expect(context).to receive(:debug).with("Creating '/api/v2/setup' with #{should}")
      provider.create(context, '/api/v2/setup', should)
    end
  end

  describe '#update' do
    it 'does nothing' do
      expect(context).to receive(:warning).with('Unable to update setup resource')
      provider.update(context, nil, nil)
    end
  end

  describe '#delete' do
    it 'does nothing' do
      expect(context).to receive(:warning).with('Unable to delete setup resource')
      provider.delete(context, nil)
    end
  end
end
