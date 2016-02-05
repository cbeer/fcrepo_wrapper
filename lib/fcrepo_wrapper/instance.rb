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
    attr_reader :options, :pid

    ##
    # @param [Hash] options
    # @option options [String] :url
    # @option options [String] :instance_dir Directory to store the fcrepo index files
    # @option options [String] :version Fcrepo version to download and install
    # @option options [String] :port port to run fcrepo on
    # @option options [String] :version_file Local path to store the currently installed version
    # @option options [String] :download_dir Local directory to store the downloaded fcrepo jar and its md5 file in (overridden by :download_path)
    # @option options [String] :download_path Local path for storing the downloaded fcrepo jar file
    # @option options [Boolean] :validate Should fcrepo_wrapper download a new md5 and (re-)validate the zip file? (default: trueF)
    # @option options [String] :md5sum Path/URL to MD5 checksum
    # @option options [Boolean] :verbose return verbose info when running fcrepo commands
    # @option options [Boolean] :ignore_md5sum
    # @option options [Hash] :fcrepo_options
    # @option options [Hash] :env
    def initialize(options = {})
      @options = options
    end

    def wrap(&_block)
      extract_and_configure
      start
      yield self
    ensure
      stop
    end

    # @return a list of arguments to pass to the JVM
    def java_options
      options.fetch(:java_options, default_java_options) + ['-jar', binary_path]
    end

    def default_java_options
      ['-Dfcrepo.log.http.api=WARN',
      # To avoid "WARN: The namespace of predicate:
      # info:fedora/fedora-system:def/relations-external#isPartOf
      # was possibly misinterpreted as:
      # info:fedora/fedora-system:def/relations-external#."
      '-Dfcrepo.log.kernel=ERROR',
      ("-Dfcrepo.home=#{fcrepo_home_dir}" if fcrepo_home_dir),
      ("-Dfcrepo.spring.jms.configuration=#{spring_noop_file}" unless jms_enabled?),
      '-Xmx512m'].compact
    end

    def fcrepo_home_dir
      options[:fcrepo_home_dir]
    end

    def process_arguments
      ["java"] + java_options +
        fcrepo_options.merge(port: port)
          .map { |k, v| ["--#{k}", "#{v}"].reject(&:empty?) }.flatten
    end

    ##
    # Start fcrepo and wait for it to become available
    def start
      extract_and_configure
      if managed?
        @pid = spawn(env, *process_arguments)

        # Wait for fcrepo to start
        while !status
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
    # Stop fcrepo and wait for it to finish exiting
    def restart
      if managed? && started?
        stop
        start
      end
    end

    ##
    # Check the status of a managed fcrepo service
    def status
      return true unless managed?
      return false if pid.nil?

      begin
        Process.getpgid(pid)

        TCPSocket.new(host, port).close

        Net::HTTP.start(host, port) do |http|
          http.request(Net::HTTP::Get.new('/'))
        end

        true
      rescue Errno::ESRCH, Errno::ECONNREFUSED
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

    ##
    # Get the port this fcrepo instance is running at
    def port
      @port ||= options[:port]
      @port ||= random_open_port.to_s
    end

    ##
    # Clean up any files fcrepo_wrapper may have downloaded
    def clean!
      stop
      remove_instance_dir!
      FileUtils.remove_entry(download_path) if File.exists?(download_path)
      FileUtils.remove_entry(tmp_save_dir, true) if File.exists? tmp_save_dir
      FileUtils.remove_entry(md5sum_path) if File.exists? md5sum_path
      FileUtils.remove_entry(version_file) if File.exists? version_file
    end

    ##
    # Clean up any files in the fcrepo instance dir
    def remove_instance_dir!
      FileUtils.remove_entry(instance_dir, true) if File.exists? instance_dir
    end

    ##
    # Get a (likely) URL to the fcrepo instance
    def url
      "http://#{host}:#{port}/"
    end

    def configure
      raise_error_unless_extracted
    end

    def instance_dir
      @instance_dir ||= options.fetch(:instance_dir, File.join(Dir.tmpdir, File.basename(download_url, ".jar")))
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
      return instance_dir if extracted?

      jar_file = download

      FileUtils.mkdir_p instance_dir
      FileUtils.cp jar_file, binary_path
      self.extracted_version = version

      instance_dir
    end
    # rubocop:enable Lint/RescueException

    def version
      @version ||= options.fetch(:version, FcrepoWrapper.default_fcrepo_version)
    end

    protected

    def extracted?
      File.exists?(binary_path) && extracted_version == version
    end

    def download
      unless File.exists?(download_path) && validate?(download_path)
        fetch_with_progressbar download_url, download_path
        validate! download_path
      end
      download_path
    end

    def validate?(file)
      return true if options[:validate] == false

      Digest::MD5.file(file).hexdigest == expected_md5sum
    end

    def validate!(file)
      unless validate? file
        raise "MD5 mismatch" unless options[:ignore_md5sum]
      end
    end

    private

    def download_url
      @download_url ||= options.fetch(:url, default_download_url)
    end

    def default_download_url
      @default_url ||= "https://github.com/fcrepo4/fcrepo4/releases/download/fcrepo-#{version}/fcrepo-webapp-#{version}-jetty-console.jar"
    end

    def md5url
      "https://github.com/fcrepo4/fcrepo4/releases/download/fcrepo-#{version}/fcrepo-webapp-#{version}-jetty-console.jar.md5"
    end

    def fcrepo_options
      options.fetch(:fcrepo_options, headless: nil)
    end

    def env
      options.fetch(:env, {})
    end

    def download_path
      @download_path ||= options.fetch(:download_path, default_download_path)
    end

    def default_download_path
      File.join(download_dir, File.basename(download_url))
    end

    def download_dir
      @download_dir ||= options.fetch(:download_dir, Dir.tmpdir)
      FileUtils.mkdir_p @download_dir
      @download_dir
    end

    def verbose?
      !!options.fetch(:verbose, false)
    end

    def managed?
      File.exists?(instance_dir)
    end

    def version_file
      options.fetch(:version_file, File.join(instance_dir, "VERSION"))
    end

    def expected_md5sum
      @md5sum ||= options.fetch(:md5sum, open(md5file).read.split(" ").first)
    end

    def binary_path
      File.join(instance_dir, "fcrepo-webapp-#{version}-jetty-console.jar")
    end

    def md5sum_path
      File.join(download_dir, File.basename(md5url))
    end

    def tmp_save_dir
      @tmp_save_dir ||= Dir.mktmpdir
    end

    def fetch_with_progressbar(url, output)
      pbar = ProgressBar.create(title: File.basename(url), total: nil, format: "%t: |%B| %p%% (%e )")
      open(url, content_length_proc: lambda do|t|
        if t && 0 < t
          pbar.total = t
        end
      end,
                progress_proc: lambda do|s|
                  pbar.progress = s
                end) do |io|
        IO.copy_stream(io, output)
      end
    end

    def md5file
      unless File.exists? md5sum_path
        fetch_with_progressbar md5url, md5sum_path
      end

      md5sum_path
    end

    def extracted_version
      File.read(version_file).strip if File.exists? version_file
    end

    def extracted_version=(version)
      File.open(version_file, "w") do |f|
        f.puts version
      end
    end

    def random_open_port
      socket = Socket.new(:INET, :STREAM, 0)
      begin
        socket.bind(Addrinfo.tcp('127.0.0.1', 0))
        socket.local_address.ip_port
      ensure
        socket.close
      end
    end

    def raise_error_unless_extracted
      raise RuntimeError, "there is no fcrepo instance at #{instance_dir}.  Run FcrepoWrapper.extract first." unless extracted?
    end

    def spring_noop_file
      'file://' + File.expand_path('../../../data/spring-noop.xml', __FILE__)
    end

    def jms_enabled?
      options.fetch(:enable_jms, true)
    end
  end
end
