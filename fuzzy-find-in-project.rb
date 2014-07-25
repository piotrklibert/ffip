#! /usr/bin/env ruby

# Author: Justin Weiss
# This is a simple wrapper for the fuzzy_file_finder gem. It really only makes
# sense in the context of the fuzzy-find-in-project.el Emacs plugin. It takes
# a query in stdin and returns a list of matching file names in stdout.
# Usage: ./fuzzy-find-in-project.rb <project-path>
# There is currently no error handling.

require 'rubygems'
require 'fuzzy_file_finder'

BUF_SIZE = 50000
IGNORES = [
  "*.pyc", "#*#", "*.elc", "*#",
  "*.git*", "*.bzr*", "*node_modules*",
  "*migrations*", "*bower_components*", "books*"
]

def make_finder(paths)
  FuzzyFileFinder.new(paths, BUF_SIZE, IGNORES)
end


finder = make_finder(ARGV)


while string = $stdin.readline
  if string.start_with?("CHANGE_PATH")
    finder = make_finder(string.split(" ")[1..-1])
    next
  end

  if string.start_with?("FINISH")
    break
  end

  matches = finder.find(string.strip, 50)
  if matches && matches.length > 0
    matches.sort_by { |m| [-m[:score], m[:path]] }.each do |match|
      puts "%s" % match[:path]
    end
  else
    puts
  end
  puts "END"
end
