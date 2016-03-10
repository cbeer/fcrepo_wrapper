require 'fcrepo_wrapper/version'
require 'fcrepo_wrapper/configuration'
require 'fcrepo_wrapper/settings'
require 'fcrepo_wrapper/downloader'
require 'fcrepo_wrapper/md5'
require 'fcrepo_wrapper/instance'

module FcrepoWrapper
  def self.default_fcrepo_version
    '4.5.0'
  end

  def self.default_instance_options
    @default_instance_options ||= {
      port: '8080',
      version: FcrepoWrapper.default_fcrepo_version
    }
  end

  def self.default_instance_options=(options)
    @default_instance_options = options
  end

  def self.default_instance(options = {})
    @default_instance ||= FcrepoWrapper::Instance.new default_instance_options.merge(options)
  end

  ##
  # Ensures a fcrepo service is running before executing the block
  def self.wrap(options = {}, &block)
    default_instance(options).wrap &block
  end
end
