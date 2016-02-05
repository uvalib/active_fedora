source "https://rubygems.org"

# Bundler will rely on active-fedora.gemspec for dependency information.

gemspec path: File.expand_path('..', __FILE__)

gem 'byebug' unless ENV['TRAVIS']
gem 'pry-byebug' unless ENV['CI']

gem 'active-triples', github: "ActiveTriples/ActiveTriples", branch: 'delegate_join'
gem 'activemodel', ENV['RAILS_VERSION'] if ENV['RAILS_VERSION']
gem 'rsolr', github: 'tpendragon/rsolr', branch: 'xml_array_like_object'

group :test do
  gem 'simplecov', require: false
  gem 'coveralls', require: false
end

gem 'jruby-openssl', platform: :jruby
