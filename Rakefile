require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "algoliasearch-rails"
    gem.summary = %Q{AlgoliaSearch integration to your favorite ORM}
    gem.description = %Q{AlgoliaSearch integration to your favorite ORM}
    gem.homepage = "http://github.com/algolia/algoliasearch-client-rails"
    gem.email = "contact@algolia.com"
    gem.authors = ["Algolia"]
    gem.files.exclude 'spec/integration_spec.rb'
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require "rspec/core/rake_task"
# RSpec 2.0
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/{algoliasearch,utilities}_spec.rb'
  spec.rspec_opts = ['--backtrace']
end
task :default => :spec

desc "Generate code coverage"
RSpec::Core::RakeTask.new(:coverage) do |t|
  t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
  t.rcov = true
  t.rcov_opts = ['--exclude', 'spec']
end

desc "Run Integration Specs"
RSpec::Core::RakeTask.new(:integration) do |t|
  t.pattern = "spec/integration_spec.rb" # don't need this, it's default.
  t.rcov = true
  t.rcov_opts = ['--exclude', 'spec']
end

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "AlgoliaSearch Rails #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
