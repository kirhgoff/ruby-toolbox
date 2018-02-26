#!/usr/bin/env ruby

require 'json'
require 'rack'

# TODO: 
# dont forget about jobstreet.vn
# check why vn/th/id job details is on English
# https://au.jora.com/Aged-Care-Traineeship.-jobs-in-Sydney-NSW#email_alert_modal

# https://au.jora.com/job/Storeperson-1670b266ad85c29483afdf08c6bba41e
JOB_DETAILS=/(?:http|https):\/\/(..)\.jora\.com\/(?:job|empleo|emploi|emprego)\/(?:.*?)([a-z0-9]+)(?:\?|$|#)/

# https://au.jora.com/jobs
ALL_JOBS=/(?:http|https):\/\/(..)\.jora\.com\/(?:jobs|empleos|emplois|empregos)(?:\?|$|#)/

# https://au.jora.com/developer-jobs
KEYWORD_SEARCH=/(?:http|https):\/\/(..)\.jora\.com\/(.*?)-(?:jobs|empleos|emplois|empregos)(?:\?|$|#)/

# https://au.jora.com/jobs-in-melbourne
LOCATION_SEARCH=/(?:http|https):\/\/(..)\.jora\.com\/(?:jobs-in|empregos-em|emplois-de|empregos-em)-(.*?)(?:\?|$|#)/

# https://au.jora.com/developer-jobs-in-melbourne
KEYWORD_LOCATION_SEARCH=/(?:http|https):\/\/(..)\.jora\.com\/(.*?)-(?:jobs-in|empregos-em|emplois-de|empregos-em)-(.*?)(?:\?|$|#)/

# https://au.jora.com/j?q=developer&l=melbourne
JKL=/(?:http|https):\/\/(..)\.jora\.com\/j\?(?:.*)q=([^&]+)(?:.*)&l=([^&]+)(?:.*)(?:#|$|&)/
JLK=/(?:http|https):\/\/(..)\.jora\.com\/j\?(?:.*)l=([^&]+)(?:.*)&q=([^&]+)(?:.*)(?:#|$|&)/

SOURCE=/(?:&sp|&utm_source)=([^(&|$|#)]*)/

class UrlParser
  attr_reader :regex, :block
  
  def initialize(regex, block)
    @regex = regex
    @block = block
  end
end

PARSERS = [
  UrlParser.new(JOB_DETAILS, Proc.new { |site_id, id| {site_id: site_id, job_id: id, type: 'job_details'} }),
  UrlParser.new(ALL_JOBS, Proc.new { |site_id| {site_id: site_id, type: 'all_jobs'} }),
  UrlParser.new(KEYWORD_SEARCH, Proc.new { |site_id, keywords| {site_id: site_id, keywords: unslug(keywords), type: 'keyword_search'} }),
  UrlParser.new(LOCATION_SEARCH, Proc.new { |site_id, location| {site_id: site_id, location: unslug(location), type: 'location_search'} }),
  UrlParser.new(KEYWORD_LOCATION_SEARCH, Proc.new { |site_id, keywords, location| {site_id: site_id, keywords: unslug(keywords), location: unslug(location), type: 'keyword_location_search'} }),
  
  UrlParser.new(JKL, Proc.new { |site_id, keywords, location| {site_id: site_id, keywords: unslug(keywords), location: unslug(location), type: 'jkl'} }),
  UrlParser.new(JLK, Proc.new { |site_id, location, keywords| {site_id: site_id, keywords: unslug(keywords), location: unslug(location), type: 'jlk'} }),
]

def unslug(text)
  Rack::Utils.unescape(text.gsub('-', ' '))
end 

def parse_source(line)
  if match = line.match(SOURCE)
    return match.captures().first
  else
    return nil
  end
end

def parse_line(line)
  source = parse_source(line)
  PARSERS.each do |parser|
    if match = line.match(parser.regex)
      result = parser.block.call(match.captures)
      result = result.merge(source: source) if source
      return result.merge(url: line)
    end
  end
  nil 
end

def parse_file(file_name)
  result = []

  text = File.open(file_name).read
  text.each_line do |line|
    line = line.strip
    hash = parse_line(line)
    result << hash if hash
  end

  result
end

results = parse_file(ARGV[0])
puts JSON.pretty_generate(results)