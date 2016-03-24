require 'spec_helper'

describe FcrepoWrapper::MD5 do
  let(:options) { {} }
  let(:config) { FcrepoWrapper::Configuration.new options }
  let(:md5) { described_class.new(config) }
  let(:file) { 'Gemfile' }

  describe "#validate!" do
    subject { md5.validate!(file) }
    it { is_expected.to eq true }
  end
end
