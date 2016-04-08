require 'fcrepo_wrapper'

## These tasks get loaded into the host context when fcrepo_wrapper is required
namespace :fcrepo do
  desc "Load the fcrepo options and fcrepo instance"
  task :environment do
    @fcrepo_instance = FcrepoWrapper.default_instance
  end

  desc 'Install a clean version of fcrepo. Replaces the existing copy if there is one.'
  task clean: :environment do
    puts "Installing clean version of fcrepo at #{File.expand_path(@fcrepo_instance.instance_dir)}"
    @fcrepo_instance.remove_instance_dir!
    @fcrepo_instance.extract_and_configure
  end

  desc 'start fcrepo'
  task start: :environment do
    begin
      puts "Starting fcrepo at #{File.expand_path(@fcrepo_instance.instance_dir)} with options #{@fcrepo_instance.options}"
      @fcrepo_instance.start
    rescue => e
      if e.message.include?("Port #{@fcrepo_instance.port} is already being used by another process")
        puts "FAILED. Port #{@fcrepo_instance.port} is already being used."
        puts " Did you already have fcrepo running?"
        puts "  a) YES: Continue as you were. fcrepo is running."
        puts "  b) NO: Either set FCREPO_OPTIONS[:port] to a different value or stop the process that's using port #{@fcrepo_instance.port}."
      else
        raise "Failed to start fcrepo. #{e.class}: #{e.message}"
      end
    end
  end

  desc 'restart fcrepo'
  task restart: :environment do
    puts "Restarting fcrepo"
    @fcrepo_instance.restart
  end

  desc 'stop fcrepo'
  task stop: :environment do
    @fcrepo_instance.stop
  end
end
