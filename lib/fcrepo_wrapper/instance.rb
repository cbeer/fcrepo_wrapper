require 'digest'
require 'fileutils'
require 'open-uri'
require 'ruby-progressbar'
require 'securerandom'
require 'stringio'
require 'tmpdir'
require 'byebug'
require 'service_instance'

module FcrepoWrapper
  class Instance
    include ServiceInstance
    attr_reader :options, :pid

    ##
    # @param [Hash] options
    # @option options [String] :url
    # @option options [String] :version
    # @option options [String] :port
    # @option options [String] :version_file
    # @option options [String] :instance_dir
    # @option options [String] :download_path
    # @option options [String] :md5sum
    # @option options [String] :xml
    # @option options [Boolean] :verbose
    # @option options [Boolean] :managed
    # @option options [Boolean] :ignore_md5sum
    # @option options [Array<String>] :java_options a list of options to pass to the JVM
    # @option options [Hash] :fcrepo_options
    # @option options [Hash] :env
    def initialize(options = {})
      @options = options
    end

    def wrap(&_block)
      start
      yield self
    ensure
      stop
    end

    # @return a list of arguments to pass to the JVM
    def java_options
      options.fetch(:java_options, []) + ['-jar', binary_path]
    end

    def process_arguments
      ["java"] + java_options +
        fcrepo_options.merge(port: port)
          .map { |k, v| ["--#{k}", "#{v}"].reject(&:empty?) }.flatten
    end

    ##
    # Start Solr and wait for it to become available
    def start
      extract
      if managed?

        @pid = spawn(env, *process_arguments)

        # Wait for fcrepo to start
        until status
          sleep 1
        end
      end
    end

    ##
    # Stop fcrepo and wait for it to finish exiting
    def stop
      if managed? && started?
        Process.kill 'HUP', pid

        # Wait for fcrepo to stop
        while status
          sleep 1
        end

        Process.waitpid(pid)
      end

      @pid = nil
    end

    ##
    # Check the status of a managed fcrepo service
    def status
      return true unless managed?
      return false if pid.nil?

      begin
        Process.getpgid(pid)

        TCPSocket.new('127.0.0.1', port).close
        true
      rescue Errno::ESRCH, Errno::ECONNREFUSED
        false
      end
    end

    ##
    # Get the port this fcrepo instance is running at
    def port
      options.fetch(:port, "8080").to_s
    end

    ##
    # Get a (likely) URL to the fcrepo instance
    def url
      "http://127.0.0.1:#{port}/rest/"
    end

    private

    def default_download_url
      @default_url ||= "https://github.com/fcrepo4/fcrepo4/releases/download/fcrepo-#{version}/fcrepo-webapp-#{version}-jetty-console.jar"
    end

    def md5url
      "https://github.com/fcrepo4/fcrepo4/releases/download/fcrepo-#{version}/fcrepo-webapp-#{version}-jetty-console.jar.md5"
    end

    def version
      @version ||= options.fetch(:version, default_fcrepo_version)
    end

    def fcrepo_options
      options.fetch(:fcrepo_options, headless: nil)
    end

    def default_fcrepo_version
      FcrepoWrapper.default_fcrepo_version
    end

    def default_instance_dir
      File.join(Dir.tmpdir, File.basename(download_url, ".jar"))
    end

    def managed?
      !!options.fetch(:managed, true)
    end

    def binary_path
      File.join(instance_dir, "fcrepo-webapp-#{version}-jetty-console.jar")
    end

    # extract a copy of fcrepo to instance_dir
    # Does noting if fcrepo already exists at instance_dir
    # @return [String] instance_dir Directory where solr has been installed
    def extract
      return instance_dir if extracted?

      jar_file = download

      byebug
      FileUtils.mkdir_p instance_dir
      FileUtils.cp jar_file, binary_path
      self.extracted_version = version

      instance_dir
    end
  end
end
