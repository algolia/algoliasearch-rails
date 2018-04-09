source "http://rubygems.org"

gem 'json', '~> 1.8', '>= 1.8.6'
gem 'algoliasearch', '>= 1.23.0', '< 2.0.0'

if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx'
  gem 'rubysl', '~> 2.0', :platform => :rbx
end

group :test do
  rails_version = ENV["RAILS_VERSION"] ? "~> #{ENV["RAILS_VERSION"]}" : '>= 3.2.0'
  gem 'rails', rails_version
  if defined?(RUBY_VERSION) && RUBY_VERSION == "1.8.7"
    gem 'i18n', '< 0.7'
    gem 'highline', '< 1.7'
    gem 'addressable', '<= 2.2.7'
    gem 'rack-cache', '< 1.3'
    gem 'mime-types', '< 2.6'
    gem 'net-http-persistent', '< 3.0'
    gem 'faraday', '< 0.10'
  elsif defined?(RUBY_VERSION) && RUBY_VERSION == "1.9.3"
    gem 'rack', '< 2'
    gem 'nokogiri', '< 1.7.0'
    if Gem::Version.new(ENV['RAILS_VERSION'] || '3.2.0') >= Gem::Version.new('4.0')
      gem 'mime-types', '~> 2.6'
    else
      gem 'mime-types', '< 3'
    end
  end
  if defined?(RUBY_VERSION) &&
     defined?(RUBY_ENGINE) &&
     RUBY_ENGINE == 'ruby' &&
     Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.1')
    gem 'net-http-persistent', '< 3.0'
  end
  gem 'rspec', '>= 2.5.0', '< 3.0'
  gem 'sqlite3', :platform => [:rbx, :ruby]
  gem 'jdbc-sqlite3', :platform => :jruby
  gem 'activerecord-jdbc-adapter', :platform => :jruby
  gem 'activerecord-jdbcsqlite3-adapter', :platform => :jruby
  gem 'redgreen'

  sequel_version = ENV['SEQUEL_VERSION'] ? "~> #{ENV['SEQUEL_VERSION']}" : '>= 4.0'
  gem 'sequel', sequel_version
end

group :development do
  gem 'travis'
  gem 'rake', '~> 10.1.0'
  gem 'rdoc'
end

group :test, :development do
  gem 'will_paginate', '>= 2.3.15'
  if defined?(RUBY_VERSION) &&
     defined?(RUBY_ENGINE) &&
     RUBY_ENGINE == 'ruby' &&
     Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2')
    gem 'kaminari', '< 1'
  else
    gem 'kaminari'
  end
end
