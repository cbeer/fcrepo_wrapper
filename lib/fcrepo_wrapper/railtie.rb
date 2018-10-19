module FcrepoWrapper
  class Railtie < Rails::Railtie
    rake_tasks do
      require 'fcrepo_wrapper/rake_task'
    end
  end
end
