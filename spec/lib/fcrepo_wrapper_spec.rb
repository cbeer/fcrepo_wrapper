require 'spec_helper'

describe FcrepoWrapper do
  describe ".wrap" do
    it "should launch fcrepo" do
      FcrepoWrapper.wrap do |fcrepo|
        expect do
          Timeout::timeout(15) do
            TCPSocket.new('127.0.0.1', fcrepo.port).close
          end
        end.not_to raise_exception
      end
    end
  end
end
