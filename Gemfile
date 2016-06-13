ruby '1.9.3', engine: 'jruby', engine_version: '1.7.13'

source 'https://rubygems.org'

gem 'myst', path: '/opt/ernest-libraries/myst/', platform: :jruby

gem 'sinatra'
gem 'nokogiri', platform: :jruby

group :development, :test do
  gem 'pry'
end

group :test do
  gem 'rspec'
  gem 'rubocop',   require: false
  gem 'simplecov', require: false
end
