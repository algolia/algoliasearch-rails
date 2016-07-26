source "http://rubygems.org"

gem 'json', '>= 1.5.1'
gem 'algoliasearch', '~> 1.8.1'
gem 'rubysl', '~> 2.0', :platform => :rbx

group :test do
  rails_version = ENV["RAILS_VERSION"] ? "~> #{ENV["RAILS_VERSION"]}" : '>= 3.2.0'
  gem 'rails', rails_version
  if defined?(RUBY_VERSION) && RUBY_VERSION == "1.8.7"
    gem 'i18n', '< 0.7'
    gem 'highline', '< 1.7'
    gem 'addressable', '<= 2.2.7'
    gem 'rack-cache', '< 1.3'
    gem 'mime-types', '< 2.6'
  end
  gem 'rspec', '>= 2.5.0', '< 3.0'
  gem 'sqlite3', :platform => [:rbx, :ruby]
  gem 'jdbc-sqlite3', :platform => :jruby
  gem 'activerecord-jdbc-adapter', :platform => :jruby
  gem 'activerecord-jdbcsqlite3-adapter', :platform => :jruby
  gem 'redgreen'
  gem 'sequel'
end

group :development do
  gem 'travis'
  gem 'rake', '~> 10.1.0'
  gem 'rdoc'
end

group :test, :development do
  gem 'will_paginate', '>= 2.3.15'
  gem 'kaminari'
end
