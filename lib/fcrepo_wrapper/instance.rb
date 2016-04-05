require 'digest'
require 'fileutils'
require 'json'
require 'net/http'
require 'open-uri'
require 'ruby-progressbar'
require 'securerandom'
require 'socket'
require 'stringio'
require 'tmpdir'

module FcrepoWrapper
  class Instance
    attr_reader :config, :pid

    ##
    # @param [Hash] options
    # @option options [String] :url
    # @option options [String] :instance_dir Directory to store the fcrepo index files
    # @option options [String] :version Fcrepo version to download and install
    # @option options [String] :port port to run fcrepo on
    # @option options [String] :version_file Local path to store the currently installed version
    # @option options [String] :download_dir Local directory to store the downloaded fcrepo jar and its md5 file in (overridden by :download_path)
    # @option options [String] :download_path Local path for storing the downloaded fcrepo jar file
    # @option options [Boolean] :validate Should fcrepo_wrapper download a new md5 and (re-)false the zip file? (default: trueF)
    # @option options [String] :md5sum Path/URL to MD5 checksum
    # @option options [Boolean] :verbose return verbose info when running fcrepo commands
    # @option options [Boolean] :ignore_md5sum
    # @option options [Hash] :fcrepo_options
    # @option options [Hash] :env
    def initialize(options = {})
      @config = Settings.new(Configuration.new(options))
    end

    def md5
      @md5 ||= MD5.new(config)
    end

    def wrap(&_block)
      extract_and_configure
      start
      yield self
    ensure
      stop
    end

    def process_arguments
      ["java"] + config.java_options +
        config.fcrepo_options.merge(port: port)
          .map { |k, v| ["--#{k}", "#{v}"].reject(&:empty?) }.flatten
    end

    ##
    # Start fcrepo and wait for it to become available
    def start
      extract_and_configure
      if config.managed?
        @pid = spawn(config.env, *process_arguments)

        # Wait for fcrepo to start
        while !status
          sleep 1
        end
      end
    end

    ##
    # Stop fcrepo and wait for it to finish exiting
    def stop
      if config.managed? && started?
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
    # Stop fcrepo and wait for it to finish exiting
    def restart
      if config.managed? && started?
        stop
        start
      end
    end

    ##
    # Check the status of a managed fcrepo service
    def status
      return true unless config.managed?
      return false if pid.nil?

      begin
        Process.getpgid(pid)
      rescue Errno::ESRCH
        return false
      end

      begin
        TCPSocket.new(host, port).close

        Net::HTTP.start(host, port) do |http|
          http.request(Net::HTTP::Get.new('/'))
        end

        true
      rescue Errno::ECONNREFUSED, Errno::EINVAL
        false
      end
    end

    ##
    # Is fcrepo running?
    def started?
      !!status
    end

    ##
    # Get the host this fcrepo instance is bound to
    def host
      '127.0.0.1'
    end

    def port
      config.port
    end

    ##
    # Get a (likely) URL to the fcrepo instance
    def url
      "http://#{host}:#{port}/"
    end

    def version
      config.version
    end

    def instance_dir
      config.instance_dir
    end

    def options
      config.options
    end

    ##
    # Clean up any files fcrepo_wrapper may have downloaded
    def clean!
      stop
      remove_instance_dir!
      FileUtils.remove_entry(config.download_path) if File.exists?(config.download_path)
      FileUtils.remove_entry(config.tmp_save_dir, true) if File.exists? config.tmp_save_dir
      md5.clean!
      FileUtils.remove_entry(config.version_file) if File.exists? config.version_file
    end

    ##
    # Clean up any files in the fcrepo instance dir
    def remove_instance_dir!
      FileUtils.remove_entry(config.instance_dir, true) if File.exists? config.instance_dir
    end

    def configure
      raise_error_unless_extracted
    end

    def extract_and_configure
      instance_dir = extract
      configure
      instance_dir
    end

    # extract a copy of fcrepo to instance_dir
    # Does noting if fcrepo already exists at instance_dir
    # @return [String] instance_dir Directory where fcrepo has been installed
    def extract
      return config.instance_dir if extracted?

      jar_file = download

      FileUtils.mkdir_p config.instance_dir
      FileUtils.cp jar_file, config.binary_path
      self.extracted_version = config.version

      config.instance_dir
    end
    # rubocop:enable Lint/RescueException

    protected

    def extracted?
      File.exists?(config.binary_path) && extracted_version == config.version
    end

    def download
      unless File.exists?(config.download_path) && md5.validate?(config.download_path)
        Downloader.fetch_with_progressbar config.download_url, config.download_path
        md5.validate! config.download_path
      end
      config.download_path
    end

    private

    def extracted_version
      File.read(config.version_file).strip if File.exists? config.version_file
    end

    def extracted_version=(version)
      File.open(config.version_file, "w") do |f|
        f.puts version
      end
    end

    def raise_error_unless_extracted
      raise RuntimeError, "there is no fcrepo instance at #{config.instance_dir}.  Run FcrepoWrapper.extract first." unless extracted?
    end
  end
end
