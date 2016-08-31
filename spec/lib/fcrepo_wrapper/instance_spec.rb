require 'spec_helper'

describe FcrepoWrapper::Instance do
  let(:wrapper) { described_class.new }

  describe "#host" do
    subject { wrapper.host }
    it { is_expected.to eq '127.0.0.1' }
  end

  describe "#port" do
    subject { wrapper.port }
    it { is_expected.to eq '8080' }
  end

  describe "#url" do
    subject { wrapper.url }
    it { is_expected.to eq 'http://127.0.0.1:8080/' }
  end

  describe "#version" do
    subject { wrapper.version }
    it { is_expected.to eq FcrepoWrapper.default_fcrepo_version }
  end

  describe "#md5" do
    subject { wrapper.md5 }
    it { is_expected.to be_instance_of FcrepoWrapper::MD5 }
  end

  describe "#instance_dir" do
    subject { wrapper.instance_dir }
    it { is_expected.to start_with Dir.tmpdir }
  end

  describe "#options" do
    subject { wrapper.options }
    it { is_expected.to eq({}) }
  end 
end
