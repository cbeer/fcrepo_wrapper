require 'fcrepo_wrapper/version'
require 'fcrepo_wrapper/instance'

module FcrepoWrapper
  def self.default_fcrepo_version
    '4.3.0'
  end

  def self.default_instance(options = {})
    @default_instance ||= FcrepoWrapper::Instance.new options
  end

  ##
  # Ensures a Solr service is running before executing the block
  def self.wrap(options = {}, &block)
    default_instance(options).wrap &block
  end
end
