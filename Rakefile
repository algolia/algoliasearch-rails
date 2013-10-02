require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "algoliasearch-rails"
    gem.summary = %Q{AlgoliaSearch integration to your favorite ORM}
    gem.description = %Q{AlgoliaSearch integration to your favorite ORM}
    gem.homepage = "http://github.com/algolia/algoliasearch-rails"
    gem.email = "contact@algolia.com"
    gem.authors = ["Algolia"]
    gem.files.exclude 'spec/integration_spec.rb'
    gem.license = "MIT"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::RubygemsDotOrgTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "AlgoliaSearch Rails #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec)

task :default => :spec
