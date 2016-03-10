require 'spec_helper'

describe FcrepoWrapper::Instance do
  let(:solr_instance) { described_class.new }

  describe "#host" do
    subject { solr_instance.host }
    it { is_expected.to eq '127.0.0.1' }
  end

  describe "#port" do
    subject { solr_instance.port }
    it { is_expected.to eq '8080' }
  end

  describe "#url" do
    subject { solr_instance.url }
    it { is_expected.to eq 'http://127.0.0.1:8080/' }
  end

  describe "#version" do
    subject { solr_instance.version }
    it { is_expected.to eq '4.5.0' }
  end

  describe "#md5", skip: true do
    subject { solr_instance.md5 }
    it { is_expected.to be_instance_of FcrepoWrapper::MD5 }
  end
end

