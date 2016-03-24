module FcrepoWrapper
  class Configuration
    attr_reader :options
    def initialize(options)
      @options = read_config(options[:config], options[:verbose])
                   .merge options
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
      !!options.fetch(:verbose, false)
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
      options[:fcrepo_home_dir]
    end

    def port
      # Check if the port option has been explicitly set to nil.
      # this means to start fcrepo_wrapper on a random open port
      return nil if options.key?(:port) && !options[:port]
      options[:port] || FcrepoWrapper.default_instance_options[:port]
    end

    def validate
      options.fetch(:validate, true)
    end

    def md5sum
      options.fetch(:md5sum, nil)
    end

    private

      def read_config(config_file, verbose)
        default_configuration_paths.each do |p|
          path = File.expand_path(p)
          config_file ||= path if File.exist? path
        end

        unless config_file
          $stdout.puts "No config specified" if verbose
          return {}
        end

        $stdout.puts "Loading configuration from #{config_file}" if verbose
        config = YAML.load(ERB.new(IO.read(config_file)).result(binding))
        unless config
          $stderr.puts "Unable to parse config #{config_file}" if verbose
          return {}
        end
        config.each_with_object({}) { |(k, v), h| h[k.to_sym] = v.to_s }
      end

      def default_configuration_paths
        ['.fcrepo_wrapper', '~/.fcrepo_wrapper']
      end

      def download_dir
        @download_dir ||= options.fetch(:download_dir, Dir.tmpdir)
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
