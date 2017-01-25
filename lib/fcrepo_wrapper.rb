require 'fcrepo_wrapper/version'
require 'fcrepo_wrapper/configuration'
require 'fcrepo_wrapper/settings'
require 'fcrepo_wrapper/downloader'
require 'fcrepo_wrapper/md5'
require 'fcrepo_wrapper/instance'

module FcrepoWrapper
  def self.default_fcrepo_version
    '4.7.1'
  end

  def self.default_fcrepo_port
    '8080'
  end

  def self.default_instance(options = {})
    @default_instance ||= FcrepoWrapper::Instance.new options
  end

  ##
  # Ensures a fcrepo service is running before executing the block
  def self.wrap(options = {}, &block)
    default_instance(options).wrap &block
  end
end
