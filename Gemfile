source "http://rubygems.org"

gem 'json', '>= 1.5.1'
gem 'algoliasearch', '~> 1.2'
gem 'rubysl', '~> 2.0', platform: :rbx

group :test do 
  gem 'rspec', '>= 2.5.0'
  gem 'activerecord', '>= 3.0.7'
  if defined?(JRUBY_VERSION)
    gem 'jdbc-sqlite3'
    gem 'activerecord-jdbc-adapter'
    gem 'activerecord-jdbcsqlite3-adapter'
  else
    gem 'sqlite3'
  end
  gem 'autotest'
  gem 'autotest-fsevent'
  gem 'redgreen'
  gem 'autotest-growl'
end

group :development do
  gem 'will_paginate', '>= 2.3.15'
  gem 'kaminari'
  gem 'travis'
  gem 'rake'
  gem 'rdoc'
end
