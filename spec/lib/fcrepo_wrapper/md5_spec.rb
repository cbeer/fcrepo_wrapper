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
      let(:options) { { md5sum: '75e5b2fea7e7b756fa4ad4ca58e96b8c' } }
      it "doesn't raise an error" do
        expect { subject }.not_to raise_error
      end
    end
  end
end
