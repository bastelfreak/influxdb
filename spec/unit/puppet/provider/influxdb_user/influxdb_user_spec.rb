# frozen_string_literal: true

require 'spec_helper'
require 'json'

ensure_module_defined('Puppet::Provider::InfluxdbUser')
require 'puppet/provider/influxdb_user/influxdb_user'
require_relative '../../../../../lib/puppet_x/puppetlabs/influxdb/influxdb'
include PuppetX::Puppetlabs::PuppetlabsInfluxdb

RSpec.describe Puppet::Provider::InfluxdbUser::InfluxdbUser do
  subject(:provider) { described_class.new }

  let(:context) { instance_double('Puppet::ResourceApi::BaseContext', 'context') }

  let(:attrs) do
    {
      name: {
        type: 'String',
      },
      password: {
        type: 'Optional[Sensitive[String]]',
      },
      status: {
        type: 'Enum[active, inactive]',
      }
    }
  end

  let(:user_response) do
    [{
      'links' => {
        'self' => '/api/v2/users'
      },
      'users' => [
        {
          'links' => {
            'self' => '/api/v2/users/123'
          },
          'id' => '123',
          'name' => 'Bob',
          'status' => 'active'
        },
      ]
    }]
  end

  describe '#get' do
    # rubocop:disable RSpec/SubjectStub
    it 'processes resources' do
      provider.instance_variable_set('@use_ssl', true)
      provider.instance_variable_set('@host', 'foo.bar.com')
      provider.instance_variable_set('@port', 8086)
      provider.instance_variable_set('@token_file', '/root/.influxdb_token')
      provider.instance_variable_set('@token', RSpec::Puppet::Sensitive.new('puppetlabs'))

      allow(provider).to receive(:influx_get).with('/api/v2/users').and_return(user_response)

      should_hash = [
        {
          use_ssl: true,
          host: 'foo.bar.com',
          port: 8086,
          token: RSpec::Puppet::Sensitive.new('puppetlabs'),
          token_file: '/root/.influxdb_token',
          name: 'Bob',
          ensure: 'present',
          status: 'active',
        },
      ]

      expect(provider.get(context)).to eq should_hash
    end

    context 'when using the system store' do
      it 'configures and uses the ssl context' do
        resources = [
          {
            use_ssl: true,
            use_system_store: true,
            host: 'foo.bar.com',
            port: 8086,
            token: RSpec::Puppet::Sensitive.new('puppetlabs'),
            token_file: '/root/.influxdb_token',
            name: 'Bob',
            ensure: 'present',
            status: 'active',
          },
        ]

        # canonicalize will set up the ssl_context and add it to the @client_options hash
        provider.canonicalize(context, resources)
        expect(provider.instance_variable_get('@client_options').key?(:ssl_context)).to eq true
      end

      it 'checks for a valid CA bundle' do
        resources = [
          {
            use_ssl: true,
            use_system_store: true,
            ca_bundle: '/not/a/file',
            host: 'foo.bar.com',
            port: 8086,
            token: RSpec::Puppet::Sensitive.new('puppetlabs'),
            token_file: '/root/.influxdb_token',
            name: 'Bob',
            ensure: 'present',
            status: 'active',
          },
        ]

        provider.canonicalize(context, resources)
        expect(instance_variable_get('@logs').any? { |log| log.message == 'No CA bundle found at /not/a/file' }).to eq true
      end
    end

    context 'when not using the system store' do
      it 'does not configure and uses the ssl context' do
        resources = [
          {
            use_ssl: true,
            use_system_store: false,
            host: 'foo.bar.com',
            port: 8086,
            token: RSpec::Puppet::Sensitive.new('puppetlabs'),
            token_file: '/root/.influxdb_token',
            name: 'Bob',
            ensure: 'present',
            status: 'active',
          },
        ]

        provider.canonicalize(context, resources)
        expect(provider.instance_variable_get('@client_options').key?(:ssl_context)).to eq false
      end
    end
  end

  describe '#create' do
    it 'creates users' do
      should_hash = {
        name: 'Bob',
        ensure: 'present',
        status: 'active',
      }

      post_args = ['/api/v2/users', JSON.dump({ name: 'Bob' })]

      expect(provider).to receive(:influx_post).with(*post_args)

      expect(context).to receive(:debug).with("Creating '#{should_hash[:name]}' with #{should_hash.inspect}")
      provider.create(context, should_hash[:name], should_hash)
    end
  end

  describe '#update' do
    let(:should_hash) do
      {
        name: 'puppet_data',
        org: 'puppetlabs',
        members: ['Alice', 'Bob'],
        retention_rules: [{
          type: 'expire',
          everySeconds: 2_592_000,
          shardGroupDurationSeconds: 604_800
        }]
      }
    end

    it 'updates users' do
      should_hash = {
        name: 'Bob',
        ensure: 'present',
        status: 'inactive'
      }

      provider.instance_variable_set(
        '@user_map',
        [
          {
            'links' => {
              'self' => '/api/v2/users/123'
            },
            'id' => '123',
            'name' => 'Bob',
            'status' => 'active'
          },
        ],
      )

      patch_args = ['/api/v2/users/123', JSON.dump({ name: should_hash[:name], status: should_hash[:status] })]

      expect(context).to receive(:debug).with("Updating '#{should_hash[:name]}' with #{should_hash.inspect}")
      expect(provider).to receive(:influx_patch).with(*patch_args)

      provider.update(context, should_hash[:name], should_hash)
    end
  end

  describe '#delete' do
    it 'deletes resources' do
      should_hash = {
        name: 'Bob',
        ensure: 'present',
        status: 'inactive'
      }

      provider.instance_variable_set(
        '@user_map',
        [
          {
            'links' => {
              'self' => '/api/v2/users/123'
            },
            'id' => '123',
            'name' => 'Bob',
            'status' => 'active'
          },
        ],
      )

      expect(context).to receive(:debug).with("Deleting '#{should_hash[:name]}'")
      expect(provider).to receive(:influx_delete).with('/api/v2/users/123')

      provider.delete(context, should_hash[:name])
    end
  end
end
