require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

require './spec/support/samples/active_record.rb'
Dir['./spec/support/**/*.rb'].each {|file| require file }
