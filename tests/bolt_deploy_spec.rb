# frozen_string_literal: true
require 'rspec'
require 'bolt_spec/plans'

RSpec.configure { |c| c.add_setting :module_path, default: File.expand_path('../spec/fixtures/modules', __dir__) }
BoltSpec::Plans.init

describe 'ai_bridge::deploy' do
  include BoltSpec::Plans

  def modulepath
    File.expand_path('../spec/fixtures/modules', __dir__)
  end

  let(:parameters) do
    { 'targets' => ['test.example.net'], 'config' => { 'master_key' => 'test-key', 'backend' => 'ollama',
      'upstream_model' => 'test-model', 'upstream_base_url' => 'http://localhost:11434', 'manage_tls' => false } }
  end

  it 'checks an existing runtime by default and applies the module' do
    expect_task('ai_bridge::docker_runtime').with_params('install_docker' => false).always_return('changed' => false)
    allow_apply_prep
    allow_apply
    expect(run_plan('ai_bridge::deploy', parameters)).to be_ok
  end

  it 'passes explicit installation consent to the runtime task' do
    expect_task('ai_bridge::docker_runtime').with_params('install_docker' => true).always_return('changed' => true)
    allow_apply_prep
    allow_apply
    expect(run_plan('ai_bridge::deploy', parameters.merge('install_docker' => true))).to be_ok
  end

  it 'rejects a missing key before any task is run' do
    parameters['config'].delete('master_key')
    result = run_plan('ai_bridge::deploy', parameters)
    expect(result).not_to be_ok
    expect(result.value.message).to include('config.master_key')
  end

  it 'stops before apply when the runtime check fails' do
    expect_task('ai_bridge::docker_runtime').error_with('kind' => 'test/runtime', 'msg' => 'daemon unavailable')
    expect(run_plan('ai_bridge::deploy', parameters)).not_to be_ok
  end
end
