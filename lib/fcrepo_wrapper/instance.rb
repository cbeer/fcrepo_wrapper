require 'digest'
require 'fileutils'
require 'open-uri'
require 'ruby-progressbar'
require 'securerandom'
require 'stringio'
require 'tmpdir'
require 'byebug'

module FcrepoWrapper
  class Instance
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

    ##
    # Start Solr and wait for it to become available
    def start
      extract
      if managed?
        args = ["java", "-jar", fcrepo_binary] + fcrepo_options.merge(port: port).map { |k, v| ["--#{k}", "#{v}"].reject(&:empty?) }.flatten

        @pid = spawn(env, *args)

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
    # Is Solr running?
    def started?
      !!status
    end

    ##
    # Get the port this fcrepo instance is running at
    def port
      options.fetch(:port, "8080").to_s
    end

    ##
    # Clean up any files fcrepo_wrapper may have downloaded
    def clean!
      stop
      FileUtils.remove_entry(download_path) if File.exists? download_path
      FileUtils.remove_entry(tmp_save_dir, true) if File.exists? tmp_save_dir
      FileUtils.remove_entry(instance_dir, true) if File.exists? instance_dir
      FileUtils.remove_entry(md5sum_path) if File.exists? md5sum_path
      FileUtils.remove_entry(version_file) if File.exists? version_file
    end

    ##
    # Get a (likely) URL to the fcrepo instance
    def url
      "http://127.0.0.1:#{port}/fcrepo/"
    end

    protected

    def extract
      return fcrepo_dir if File.exists?(fcrepo_binary) && extracted_version == version

      jar_path = download

      FileUtils.mkdir_p fcrepo_path
      FileUtils.cp jar_path, fcrepo_binary
      self.extracted_version = version

      configure

      fcrepo_dir
    end

    def download
      unless File.exists?(download_path) && validate?(download_path)
        fetch_with_progressbar download_url, download_path
        validate! download_path
      end

      download_path
    end

    def validate?(file)
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

    def version
      @version ||= options.fetch(:version, default_fcrepo_version)
    end

    def fcrepo_options
      options.fetch(:fcrepo_options, headless: nil)
    end

    def env
      options.fetch(:env, {})
    end

    def default_fcrepo_version
      FcrepoWrapper.default_fcrepo_version
    end

    def download_path
      @download_path ||= options.fetch(:download_path, default_download_path)
    end

    def default_download_path
      File.join(Dir.tmpdir, File.basename(download_url))
    end

    def fcrepo_dir
      @fcrepo_dir ||= options.fetch(:instance_dir, File.join(Dir.tmpdir, File.basename(download_url, ".jar")))
    end

    def verbose?
      !!options.fetch(:verbose, false)
    end

    def managed?
      !!options.fetch(:managed, true)
    end

    def version_file
      options.fetch(:version_file, File.join(fcrepo_dir, "VERSION"))
    end

    def expected_md5sum
      @md5sum ||= options.fetch(:md5sum, open(md5file).read.split(" ").first)
    end

    def fcrepo_binary
      File.join(fcrepo_dir, "fcrepo-webapp-#{version}-jetty-console.jar")
    end

    def md5sum_path
      File.join(Dir.tmpdir, File.basename(md5url))
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

    def configure
    end
  end
end
