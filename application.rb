# -*- encoding : utf-8 -*-
require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'haml'
require 'logger'

configure do
  LOG = Logger.new(STDOUT)
  LOG.level = Logger.const_get ENV['LOG_LEVEL'] || 'DEBUG'
  set :views, '.'
end

get '/' do
  markdown :README, layout_engine: :haml
end