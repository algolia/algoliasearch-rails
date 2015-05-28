source "http://rubygems.org"

gem 'json', '>= 1.5.1'
gem 'algoliasearch', '~> 1.2.14'
gem 'rubysl', '~> 2.0', :platform => :rbx

group :test do
  gem 'rspec', '>= 2.5.0', '< 3.0'
  if defined?(RUBY_VERSION) && RUBY_VERSION == "1.8.7"
    gem 'rails', '>= 3.2.0', '< 4.0'
    gem 'i18n', '< 0.7'
    gem 'highline', '< 1.7'
  else
    gem 'rails', '>= 3.2.0'
  end
  gem 'sqlite3', :platform => [:rbx, :ruby]
  gem 'jdbc-sqlite3', :platform => :jruby
  gem 'activerecord-jdbc-adapter', :platform => :jruby
  gem 'activerecord-jdbcsqlite3-adapter', :platform => :jruby
  gem 'autotest'
  gem 'autotest-fsevent', '~> 0.2.10'
  gem 'redgreen'
  gem 'autotest-growl'
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
