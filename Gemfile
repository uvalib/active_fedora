source "https://rubygems.org"

# Bundler will rely on active-fedora.gemspec for dependency information.

gemspec path: File.expand_path('..', __FILE__)

gem 'byebug' unless ENV['TRAVIS']

group :test do
  gem 'simplecov', require: false
  gem 'coveralls', require: false
end

if RUBY_ENGINE == 'jruby'
  gem 'slop', '~> 3.6.0' # https://github.com/leejarvis/slop/issues/160
  gem 'jruby-openssl', platform: :jruby
end
