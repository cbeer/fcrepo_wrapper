require 'yaml'
require 'erb'
require 'socket'

module FcrepoWrapper
  class Configuration
    attr_reader :options
    def initialize(options)
      @config = options[:config]
      @verbose = options[:verbose]
      @options = load_configs(Array(options[:config])).merge(options)
    end

    def instance_dir
      @instance_dir ||= options.fetch(:instance_dir, File.join(Dir.tmpdir, File.basename(download_url, ".jar")))
    end

    def download_url
      @download_url ||= options.fetch(:url, default_download_url)
    end

    def default_download_path
      File.join(download_dir, File.basename(download_url))
    end

    def download_path
      @download_path ||= options.fetch(:download_path, default_download_path)
    end

    def ignore_md5sum
      options.fetch(:ignore_md5sum, false)
    end

    def md5sum_path
      File.join(download_dir, File.basename(md5url))
    end

    def tmp_save_dir
      @tmp_save_dir ||= Dir.mktmpdir
    end

    def version
      @version ||= options.fetch(:version, FcrepoWrapper.default_fcrepo_version)
    end

    def version_file
      options.fetch(:version_file, File.join(instance_dir, "VERSION"))
    end

    def binary_path
      File.join(instance_dir, "fcrepo-webapp-#{version}-jetty-console.jar")
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

    def verbose?
      @verbose || (options && !!options.fetch(:verbose, false))
    end

    def managed?
      File.exists?(instance_dir)
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
      if options[:fcrepo_home_dir]
        options[:fcrepo_home_dir]
      elsif defined? Rails
        File.join(Rails.root, 'tmp', 'fcrepo4-data')
      else
        Dir.mktmpdir
      end
    end

    def port
      # Check if the port option has been explicitly set to nil.
      # this means to start fcrepo_wrapper on a random open port
      return nil if options.key?(:port) && !options[:port]
      options[:port] || FcrepoWrapper.default_fcrepo_port
    end

    def validate
      options.fetch(:validate, true)
    end

    def md5sum
      options.fetch(:md5sum, nil)
    end

    private

      def load_configs(config_files)
        config = {}

        (default_configuration_paths + config_files.compact).each do |p|
          path = File.expand_path(p)
          next unless File.exist? path
          config.merge!(read_config(path))
        end

        config
      end

      def read_config(config_file)
        $stdout.puts "Loading configuration from #{config_file}" if verbose?
        config = YAML.load(ERB.new(IO.read(config_file)).result(binding))
        unless config
          $stderr.puts "Unable to parse config #{config_file}" if verbose?
          return {}
        end
        convert_keys(config)
      end

      def convert_keys(hash)
        hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
      end

      def default_configuration_paths
        ['~/.fcrepo_wrapper.yml', '~/.fcrepo_wrapper', '.fcrepo_wrapper.yml', '.fcrepo_wrapper']
      end

      def default_download_dir
        if defined?(Rails) && Rails.root
          File.join(Rails.root, 'tmp')
        else
          Dir.tmpdir
        end
      end

      def download_dir
        @download_dir ||= options.fetch(:download_dir, default_download_dir)
        FileUtils.mkdir_p @download_dir
        @download_dir
      end

      def default_download_url
        @default_url ||= "https://github.com/fcrepo4/fcrepo4/releases/download/fcrepo-#{version}/fcrepo-webapp-#{version}-jetty-console.jar"
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

      def spring_noop_file
        'file://' + File.expand_path('../../../data/spring-noop.xml', __FILE__)
      end

      def jms_enabled?
        options.fetch(:enable_jms, true)
      end
  end
end
