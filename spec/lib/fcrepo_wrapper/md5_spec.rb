require 'spec_helper'

describe FcrepoWrapper::MD5 do
  let(:options) { {} }
  let(:config) { FcrepoWrapper::Configuration.new options }
  let(:md5) { described_class.new(config) }
  let(:file) { 'spec/fixtures/sample_config.yml' }

  describe "#validate!" do
    subject { md5.validate!(file) }
    context "with a checksum mismatch" do
      it "raises an error" do
        expect { subject }.to raise_error "MD5 mismatch"
      end
    end

    context "with a correct checksum" do
      let(:options) { { md5sum: 'de0b8ccf94db635e149b4c01027b34c1' } }
      it "doesn't raise an error" do
        expect { subject }.not_to raise_error
      end
    end
  end
end
