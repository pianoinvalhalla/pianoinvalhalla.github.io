#!/bin/env ruby

# grely

# one day it will perform
# conversion gregorio (gabc) -> lilypond

# now it only
# says if it is able to parse the given input file 

require 'polyglot'
require 'treetop'

Treetop.load File.expand_path('../lib/lygre/gabcgrammar', File.dirname(__FILE__))

parser = GabcParser.new

if ARGV.size >= 1 then
  inputf = ARGV[0]
  rf = File.open inputf
else
  rf = STDIN
end

input = rf.read

result = parser.parse(input)

if result then
  STDERR.puts 'grely thinks this is a valid gabc file.'
  exit 0
else
  STDERR.puts 'grely thinks the input is not valid gabc:'
  STDERR.puts 
  STDERR.puts "'#{parser.failure_reason}' on line #{parser.failure_line} column #{parser.failure_column}:"
  STDERR.puts input.split("\n")[parser.failure_line-1]
  STDERR.puts (" " * parser.failure_column) + "^"
  exit 1
end
