# frozen_string_literal: true

require 'spec_helper'

describe 'ai_bridge' do
  let(:facts) do
    {
      'os' => { 'family' => 'RedHat', 'name' => 'Rocky', 'release' => { 'major' => '9' } },
      'kernel' => 'Linux',
      'networking' => { 'fqdn' => 'ai-bridge.souldo.lan' },
    }
  end

  let(:base_params) do
    {
      'master_key' => sensitive('sk-bridge-test'),
      'tls_cert' => "-----BEGIN CERTIFICATE-----\nAAA\n-----END CERTIFICATE-----\n",
      'tls_key' => sensitive("-----BEGIN PRIVATE KEY-----\nBBB\n-----END PRIVATE KEY-----\n"),
    }
  end

  context 'anthropic backend (default)' do
    let(:params) { base_params.merge('upstream_api_key' => sensitive('sk-ant-xyz')) }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('ai_bridge::install').that_comes_before('Class[ai_bridge::config]') }
    it { is_expected.to contain_class('ai_bridge::config').that_notifies('Class[ai_bridge::service]') }

    it 'creates a locked system user' do
      is_expected.to contain_user('ai_bridge').with(
        'system' => true, 'shell' => '/sbin/nologin', 'home' => '/opt/ai_bridge',
      )
    end

    it 'installs podman by default' do
      is_expected.to contain_package('podman').with_ensure('installed')
    end

    it 'writes an env file with secrets, mode 0600' do
      is_expected.to contain_file('/opt/ai_bridge/ai_bridge.env').with(
        'owner' => 'ai_bridge', 'group' => 'ai_bridge', 'mode' => '0600', 'show_diff' => false,
      )
      content = catalogue.resource('file', '/opt/ai_bridge/ai_bridge.env').send(:parameters)[:content]
      content = content.unwrap if content.respond_to?(:unwrap)
      expect(content).to include('LITELLM_MASTER_KEY=sk-bridge-test')
      expect(content).to include('ANTHROPIC_API_KEY=sk-ant-xyz')
      expect(content).not_to include('OPENAI_API_KEY')
    end

    it 'renders a LiteLLM config aliasing o4-mini to the anthropic model' do
      is_expected.to contain_file('/opt/ai_bridge/config.yaml').with_mode('0640')
      content = catalogue.resource('file', '/opt/ai_bridge/config.yaml')[:content]
      expect(content).to match(/model_name: o4-mini\n\s+litellm_params:\n\s+model: anthropic\/claude-sonnet-4-5/)
      expect(content).to include('api_key: os.environ/ANTHROPIC_API_KEY')
      expect(content).to include('drop_params: true')
      expect(content).to include('master_key: os.environ/LITELLM_MASTER_KEY')
      expect(content).not_to include('api_base')
    end

    it 'does not put secret values in config.yaml' do
      content = catalogue.resource('file', '/opt/ai_bridge/config.yaml')[:content]
      expect(content).not_to include('sk-ant-xyz')
      expect(content).not_to include('sk-bridge-test')
    end

    it 'manages the TLS cert and key with safe perms' do
      is_expected.to contain_file('/opt/ai_bridge/tls/server.crt').with_mode('0644')
      is_expected.to contain_file('/opt/ai_bridge/tls/server.key').with(
        'mode' => '0600', 'owner' => 'ai_bridge', 'show_diff' => false,
      )
    end

    it 'runs the container under systemd with hardening flags' do
      is_expected.to contain_file('/etc/systemd/system/ai_bridge.service').with_mode('0644')
      unit = catalogue.resource('file', '/etc/systemd/system/ai_bridge.service')[:content]
      expect(unit).to include('ExecStart=/usr/bin/podman run')
      expect(unit).to include('--read-only')
      expect(unit).to include('--cap-drop=ALL')
      expect(unit).to include('--security-opt=no-new-privileges')
      expect(unit).to include('--env-file=/opt/ai_bridge/ai_bridge.env')
      expect(unit).to include('-p 4000:4000')
      expect(unit).to include('--ssl_certfile_path=/app/tls/server.crt')
      expect(unit).to include('--ssl_keyfile_path=/app/tls/server.key')
      expect(unit).to include('ghcr.io/berriai/litellm:main-stable')
      expect(unit).to include('User=ai_bridge')
      is_expected.to contain_service('ai_bridge').with('ensure' => 'running', 'enable' => true)
    end

    it 'does not expose Restart=no and reloads systemd' do
      is_expected.to contain_exec('ai_bridge-systemd-reload').with_refreshonly(true)
    end
  end

  context 'openai backend' do
    let(:params) do
      base_params.merge(
        'backend' => 'openai', 'upstream_model' => 'gpt-5-mini', 'upstream_api_key' => sensitive('sk-oai'),
      )
    end

    it { is_expected.to compile.with_all_deps }
    it 'aliases to openai/<model> and ships OPENAI_API_KEY' do
      content = catalogue.resource('file', '/opt/ai_bridge/config.yaml')[:content]
      expect(content).to include('model: openai/gpt-5-mini')
      expect(content).to include('api_key: os.environ/OPENAI_API_KEY')
      env = catalogue.resource('file', '/opt/ai_bridge/ai_bridge.env')[:content]
      env = env.unwrap if env.respond_to?(:unwrap)
      expect(env).to include('OPENAI_API_KEY=sk-oai')
    end
  end

  context 'ollama backend' do
    let(:params) do
      base_params.merge(
        'backend' => 'ollama', 'upstream_model' => 'qwen3:32b',
        'upstream_base_url' => 'http://ollama.souldo.lan:11434',
      )
    end

    it { is_expected.to compile.with_all_deps }
    it 'uses ollama_chat/ with api_base and no api_key' do
      content = catalogue.resource('file', '/opt/ai_bridge/config.yaml')[:content]
      expect(content).to include('model: ollama_chat/qwen3:32b')
      expect(content).to include('api_base: http://ollama.souldo.lan:11434')
      expect(content).not_to include('api_key:')
    end
  end

  context 'openai_compatible backend with key' do
    let(:params) do
      base_params.merge(
        'backend' => 'openai_compatible', 'upstream_model' => 'Qwen/Qwen3-32B',
        'upstream_base_url' => 'http://vllm.souldo.lan:8000/v1', 'upstream_api_key' => sensitive('tok'),
      )
    end

    it { is_expected.to compile.with_all_deps }
    it 'uses openai/ prefix, api_base and UPSTREAM_API_KEY' do
      content = catalogue.resource('file', '/opt/ai_bridge/config.yaml')[:content]
      expect(content).to include('model: openai/Qwen/Qwen3-32B')
      expect(content).to include('api_base: http://vllm.souldo.lan:8000/v1')
      expect(content).to include('api_key: os.environ/UPSTREAM_API_KEY')
    end
  end

  context 'extra aliases' do
    let(:params) do
      base_params.merge(
        'upstream_api_key' => sensitive('k'),
        'extra_aliases' => { 'o3' => 'anthropic/claude-opus-4-1', 'gpt-4o' => 'anthropic/claude-sonnet-4-5' },
      )
    end

    it 'renders each alias as its own model_list entry' do
      content = catalogue.resource('file', '/opt/ai_bridge/config.yaml')[:content]
      expect(content).to match(/model_name: o3\n\s+litellm_params:\n\s+model: anthropic\/claude-opus-4-1/)
      expect(content).to match(/model_name: gpt-4o\n/)
    end
  end

  context 'PE usage compatibility enabled' do
    let(:params) { base_params.merge('upstream_api_key' => sensitive('k'), 'container_runtime' => 'docker', 'normalize_usage' => true) }

    it 'ships the read-only compatibility callback and enables it' do
      is_expected.to compile.with_all_deps
      is_expected.to contain_file('/opt/ai_bridge/pe_compat.py').with_source('puppet:///modules/ai_bridge/pe_compat.py')
      is_expected.to contain_file('/opt/ai_bridge/pe_usage.py').with_source('puppet:///modules/ai_bridge/pe_usage.py')
      config = catalogue.resource('file', '/opt/ai_bridge/config.yaml')[:content]
      expect(config).to include('pe_compat.proxy_handler')
      unit = catalogue.resource('file', '/etc/systemd/system/ai_bridge.service')[:content]
      expect(unit).to include('/opt/ai_bridge/pe_compat.py:/app/pe_compat.py:ro')
      expect(unit).to include('/opt/ai_bridge/pe_usage.py:/app/pe_usage.py:ro')
    end
  end

  context 'personality unset' do
    let(:params) { base_params.merge('upstream_api_key' => sensitive('k')) }

    it 'keeps personality disabled by default and removes stale style files' do
      is_expected.to contain_file('/opt/ai_bridge/personality.txt').with_ensure('absent')
      is_expected.to contain_file('/opt/ai_bridge/personality_callback.py').with_ensure('absent')
      expect(catalogue.resource('file', '/opt/ai_bridge/config.yaml')[:content]).not_to include('personality_callback')
      expect(catalogue.resource('file', '/etc/systemd/system/ai_bridge.service')[:content]).not_to include('personality.txt:/app/')
    end
  end

  context 'personality and usage normalization enabled together' do
    let(:params) do
      base_params.merge('upstream_api_key' => sensitive('k'), 'container_runtime' => 'docker',
        'normalize_usage' => true, 'personality_prompt' => "Talk like a pirate\nKeep answers concise.")
    end

    it 'ships style as data and mounts both callbacks read-only' do
      is_expected.to compile.with_all_deps
      is_expected.to contain_file('/opt/ai_bridge/personality.txt').with(
        'content' => "Talk like a pirate\nKeep answers concise.", 'mode' => '0640', 'owner' => 'root', 'show_diff' => false,
      )
      is_expected.to contain_file('/opt/ai_bridge/personality_callback.py').with_source('puppet:///modules/ai_bridge/personality_callback.py')
      is_expected.to contain_file('/opt/ai_bridge/personality.py').with_source('puppet:///modules/ai_bridge/personality.py')
      config = catalogue.resource('file', '/opt/ai_bridge/config.yaml')[:content]
      expect(config).to include('pe_compat.proxy_handler', 'personality_callback.proxy_handler')
      expect(config).not_to include('Talk like a pirate')
      unit = catalogue.resource('file', '/etc/systemd/system/ai_bridge.service')[:content]
      %w[personality.txt personality.py personality_callback.py pe_compat.py pe_usage.py].each do |name|
        expect(unit).to include("/opt/ai_bridge/#{name}:/app/#{name}:ro")
      end
      expect(unit.scan('--env PYTHONPATH=/app').length).to eq(1)
    end
  end

  context 'personality without usage normalization' do
    let(:params) { base_params.merge('upstream_api_key' => sensitive('k'), 'personality_prompt' => 'Talk like a pirate') }

    it 'enables only the personality callback' do
      config = catalogue.resource('file', '/opt/ai_bridge/config.yaml')[:content]
      expect(config).to include('personality_callback.proxy_handler')
      expect(config).not_to include('pe_compat.proxy_handler')
      expect(catalogue.resource('file', '/etc/systemd/system/ai_bridge.service')[:content]).to include('--env PYTHONPATH=/app')
    end
  end

  context 'docker runtime' do
    let(:params) { base_params.merge('upstream_api_key' => sensitive('k'), 'container_runtime' => 'docker') }

    it 'keeps Docker bind-mounted config and TLS readable without DAC capabilities' do
      %w[/opt/ai_bridge /opt/ai_bridge/tls /opt/ai_bridge/config.yaml /opt/ai_bridge/ai_bridge.env /opt/ai_bridge/tls/server.key].each do |path|
        is_expected.to contain_file(path).with_owner('root').with_group('root')
      end
      is_expected.to contain_file('/opt/ai_bridge/ai_bridge.env').with_mode('0600')
      is_expected.to contain_file('/opt/ai_bridge/tls/server.key').with_mode('0600')
    end

    it 'installs docker and uses docker run' do
      is_expected.to contain_package('docker').with_ensure('installed')
      unit = catalogue.resource('file', '/etc/systemd/system/ai_bridge.service')[:content]
      expect(unit).to include('ExecStart=/usr/bin/docker run')
      expect(unit).to include('User=root')
    end
  end

  context 'TLS disabled' do
    let(:params) { { 'master_key' => sensitive('k'), 'upstream_api_key' => sensitive('k'), 'manage_tls' => false } }

    it { is_expected.to compile.with_all_deps }
    it 'omits ssl flags and cert files' do
      unit = catalogue.resource('file', '/etc/systemd/system/ai_bridge.service')[:content]
      expect(unit).not_to include('--ssl_certfile_path')
      is_expected.not_to contain_file('/opt/ai_bridge/tls/server.key')
    end
  end

  context 'validation' do
    context 'anthropic without key' do
      let(:params) { base_params }

      it { is_expected.to compile.and_raise_error(/upstream_api_key is required/) }
    end

    context 'ollama without base url' do
      let(:params) { base_params.merge('backend' => 'ollama') }

      it { is_expected.to compile.and_raise_error(/upstream_base_url is required/) }
    end

    context 'TLS enabled without cert' do
      let(:params) { { 'master_key' => sensitive('k'), 'upstream_api_key' => sensitive('k') } }

      it { is_expected.to compile.and_raise_error(/tls_cert and tls_key are required/) }
    end

    context 'bad backend' do
      let(:params) { base_params.merge('backend' => 'bedrock') }

      it { is_expected.to compile.and_raise_error(/Ai_bridge::Backend/) }
    end

    context 'master key not Sensitive' do
      let(:params) { base_params.merge('master_key' => 'plain', 'upstream_api_key' => sensitive('k')) }

      it { is_expected.to compile.and_raise_error(/Sensitive/) }
    end
  end

  context 'ensure => absent' do
    let(:params) { base_params.merge('upstream_api_key' => sensitive('k'), 'ensure' => 'absent') }

    it 'stops the service and removes files' do
      is_expected.to contain_service('ai_bridge').with('ensure' => 'stopped', 'enable' => false)
      is_expected.to contain_file('/etc/systemd/system/ai_bridge.service').with_ensure('absent')
      is_expected.to contain_file('/opt/ai_bridge').with('ensure' => 'absent', 'force' => true)
    end
  end
end
