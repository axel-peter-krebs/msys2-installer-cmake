#!/usr/bin/env ruby

require 'pathname'

puts 'Current path: '
puts Pathname.new($0).realpath() # implicit string conversion
