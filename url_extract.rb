#!/usr/bin/env ruby

require 'json'
require 'rack'

# TODO: 
# add th/id job details is on English

# https://au.jora.com/job/Storeperson-1670b266ad85c29483afdf08c6bba41e
JOB_DETAILS=/(?:http|https):\/\/(..)\.jora\.com\/(?:job|emploi|emprego|empleo|%E0%B8%87%E0%B8%B2%E0%B8%99|งาน|lowongan)\/(?:.*?)([a-z0-9]+)(?:\?|$|#)/

# https://au.jora.com/jobs
ALL_JOBS=/(?:http|https):\/\/(..)\.jora\.com\/(?:jobs|emplois|empregos|empleos|%E0%B8%87%E0%B8%B2%E0%B8%99|งาน|lowongankerja)(?:\?|$|#)/

# https://au.jora.com/developer-jobs
EN_FR_KEYWORD_SEARCH=/(?:http|https):\/\/(..)\.jora\.com\/(.*?)-(?:jobs|emplois)(?:\?|$|#)/
PT_ES_TH_ID_KEYWORD_SEARCH=/(?:http|https):\/\/(..)\.jora\.com\/(?:empregos-de|empleos-de|%E0%B8%87%E0%B8%B2%E0%B8%99|lowongan)-(.*?)(?:\?|$|#)/

# https://au.jora.com/jobs-in-melbourne
LOCATION_SEARCH=/(?:http|https):\/\/(..)\.jora\.com\/(?:jobs-in|emplois-de|empregos-em|empleos-en|%E0%B8%87%E0%B8%B2%E0%B8%99-%E0%B9%83%E0%B8%99|งาน-ใน|lowongan-di)-(.*?)(?:\?|$|#)/

# https://au.jora.com/developer-jobs-in-melbourne
EN_FR_KEYWORD_LOCATION_SEARCH=/(?:http|https):\/\/(..)\.jora\.com\/(.*?)-(?:jobs-in|emplois-de)-(.*?)(?:\?|$|#)/
OTHER_KEYWORD_LOCATION_SEARCH=/(?:http|https):\/\/(..)\.jora\.com\/(?:empregos-de|empleos-de|%E0%B8%87%E0%B8%B2%E0%B8%99|งาน|lowongan)-(.*?)-(?:em|en|%E0%B9%83%E0%B8%99|ใน|di)-(.*?)(?:\?|$|#)/

# https://au.jora.com/j?q=developer&l=melbourne
JKL=/(?:http|https):\/\/(..)\.jora\.com\/j\?(?:.*)q=([^&]+)(?:.*)&l=([^&]+)(?:.*)(?:#|$|&)/
JLK=/(?:http|https):\/\/(..)\.jora\.com\/j\?(?:.*)l=([^&]+)(?:.*)&q=([^&]+)(?:.*)(?:#|$|&)/

SOURCE=/(?:\?|&)(?:sp|utm_source)=([^(&|$|#)]*)/
ALERT_ID=/(?:\?|&)(?:alert_id)=([^(&|$|#)]*)/

class UrlParser
  attr_reader :regex, :block
  
  def initialize(regex, block)
    @regex = regex
    @block = block
  end
end

PARSERS = [
  UrlParser.new(JOB_DETAILS, Proc.new { |site_id, id| {site_id: site_id, job_id: id, type: 'job_details'} }),
  UrlParser.new(ALL_JOBS, Proc.new { |site_id| {site_id: site_id.first, type: 'all_jobs'} }),
  UrlParser.new(EN_FR_KEYWORD_SEARCH, Proc.new { |site_id, keywords| {site_id: site_id, keywords: unslug(keywords), type: 'keyword_search'} }),
  UrlParser.new(PT_ES_TH_ID_KEYWORD_SEARCH, Proc.new { |site_id, keywords| {site_id: site_id, keywords: unslug(keywords), type: 'keyword_search'} }),
  UrlParser.new(LOCATION_SEARCH, Proc.new { |site_id, location| {site_id: site_id, location: unslug(location), type: 'location_search'} }),
  UrlParser.new(EN_FR_KEYWORD_LOCATION_SEARCH, Proc.new { |site_id, keywords, location| {site_id: site_id, keywords: unslug(keywords), location: unslug(location), type: 'keyword_location_search'} }),
  UrlParser.new(OTHER_KEYWORD_LOCATION_SEARCH, Proc.new { |site_id, keywords, location| {site_id: site_id, keywords: unslug(keywords), location: unslug(location), type: 'keyword_location_search'} }),
  
  UrlParser.new(JKL, Proc.new { |site_id, keywords, location| {site_id: site_id, keywords: unslug(keywords), location: unslug(location), type: 'jkl'} }),
  UrlParser.new(JLK, Proc.new { |site_id, location, keywords| {site_id: site_id, keywords: unslug(keywords), location: unslug(location), type: 'jlk'} }),
]

def unslug(text)
  Rack::Utils.unescape(text.gsub('-', ' '))
end 

def also_parse(result, line, regex, symbol)
  if match = line.match(regex)
    return result.merge(symbol => match.captures().first)
  end
  return result
end

def parse_line(line)
#  source = parse_source(line)
  PARSERS.each do |parser|
    if match = line.match(parser.regex)
      result = parser.block.call(match.captures)
      result = also_parse(result, line, SOURCE, :source)
      result = also_parse(result, line, ALERT_ID, :alert_id)
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