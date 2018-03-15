#!/usr/bin/env ruby

require 'json'
require 'rack'

# TODO 
# https://in.jora.com/job/Fresher-f299e51414a435e56a4ff0328f0a480b?from_url=https%3A%2F%2Fin.jora.com%2FPart-Time-jobs-in-Bellary%2C-Karn%25C4%2581taka%3Fgclid%3DCj0KCQiAiKrUBRD6ARIsADS2OLmlwjkQb93czZtwd36i9AF-uYVZSyEKbibbJoFJakpKPPFTIpDkEBYaApFJEALw_wcB&sl=Bellary%2C+Karn%C4%81taka&sp=serp&sponsored=false&sq=Part+Time&sr=2&tk=iyf3SObCr0MLa6KVcgSD-j0w6yLizVQmWzCKO5Gap
# https://fr.jora.com/emploi/Commercial-bd1d99d04d55277356324b873b95810c?from_url=https%3A%2F%2Ffr.jora.com%2FStage-emplois-de-Principaut%25C3%25A9-de-Monaco%3Fgclid%3DEAIaIQobChMIo8mO3bW12QIVDPEbCh1RBgsnEAAYAiAAEgKhBfD_BwE%26utm_campaign%3Ddynamic%26utm_medium%3Dcpc%26utm_source%3Dgoogle&sl=Principaut%C3%A9+de+Monaco&sp=serp&sponsored=false&sq=Stage&sr=11&tk=EGdEectSMEnq9ndEJ3qM-OnAejbd3FJlmdh0Yw3b0

# https://au.jora.com/job/Storeperson-1670b266ad85c29483afdf08c6bba41e
JOB_DETAILS=/^(?:http|https):\/\/(..)\.jora\.com\/(?:job|empleo|trabajo|emploi|offre%20d'emploi|%E0%B8%87%E0%B8%B2%E0%B8%99|งาน|vaga)\/(?:.*?)([a-z0-9]+)(?:\?|$|#)/

# https://au.jora.com/jobs
ALL_JOBS=/^(?:http|https):\/\/(..)\.jora\.com\/(?:jobs|emplois|empregos|empleos|%E0%B8%87%E0%B8%B2%E0%B8%99|งาน|lowongankerja)(?:\?|$|#)/

# https://au.jora.com/developer-jobs
EN_FR_KEYWORD_SEARCH=/^(?:http|https):\/\/(..)\.jora\.com\/(.*?)-(?:jobs|emplois)(?:\?|$|#)/
PT_ES_TH_ID_KEYWORD_SEARCH=/^(?:http|https):\/\/(..)\.jora\.com\/(?:empregos-de|empleos-de|%E0%B8%87%E0%B8%B2%E0%B8%99|lowongan)-(.*?)(?:\?|$|#)/

# https://au.jora.com/jobs-in-melbourne
LOCATION_SEARCH=/^(?:http|https):\/\/(..)\.jora\.com\/(?:jobs-in|emplois-de|empregos-em|empleos-en|%E0%B8%87%E0%B8%B2%E0%B8%99-%E0%B9%83%E0%B8%99|งาน-ใน|lowongan-di)-(.*?)(?:\?|$|#)/

# https://au.jora.com/developer-jobs-in-melbourne
EN_FR_KEYWORD_LOCATION_SEARCH=/^(?:http|https):\/\/(..)\.jora\.com\/(.*?)-(?:jobs-in|emplois-de)-(.*?)(?:\?|$|#)/
OTHER_KEYWORD_LOCATION_SEARCH=/^(?:http|https):\/\/(..)\.jora\.com\/(?:empregos-de|empleos-de|%E0%B8%87%E0%B8%B2%E0%B8%99|งาน|lowongan)-(.*?)-(?:em|en|%E0%B9%83%E0%B8%99|ใน|di)-(.*?)(?:\?|$|#)/

# https://au.jora.com/j?q=developer&l=melbourne
JQL=/^(?:http|https):\/\/(..)\.jora\.com\/j\?(?:.*?)q=([^&]*)(?:.*?)&l=([^&]*)(?:.*)(?:#|$|&)/

# https://au.jora.com/j?l=melbourne&q=developer
JLQ=/^(?:http|https):\/\/(..)\.jora\.com\/j\?(?:.*?)l=([^&]*)(?:.*?)&q=([^&]*)(?:.*)(?:#|$|&)/

# https://au.jora.com/j?q=developer
JQ=/^(?:http|https):\/\/(..)\.jora\.com\/j\?(?:.*?)q=([^&]*)(?:.*?)(?:#|$|&)/

# https://au.jora.com/j?l=melbourne
JL=/^(?:http|https):\/\/(..)\.jora\.com\/j\?(?:.*?)l=([^&]*)(?:.*?)(?:#|$|&)/

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
  
  UrlParser.new(OTHER_KEYWORD_LOCATION_SEARCH, Proc.new { |site_id, keywords, location| {site_id: site_id, keywords: unslug(keywords), location: unslug(location), type: 'keyword_location_search'} }),
  UrlParser.new(EN_FR_KEYWORD_LOCATION_SEARCH, Proc.new { |site_id, keywords, location| {site_id: site_id, keywords: unslug(keywords), location: unslug(location), type: 'keyword_location_search'} }),
  UrlParser.new(LOCATION_SEARCH, Proc.new { |site_id, location| {site_id: site_id, location: unslug(location), type: 'location_search'} }),
  UrlParser.new(EN_FR_KEYWORD_SEARCH, Proc.new { |site_id, keywords| {site_id: site_id, keywords: unslug(keywords), type: 'keyword_search'} }),
  UrlParser.new(PT_ES_TH_ID_KEYWORD_SEARCH, Proc.new { |site_id, keywords| {site_id: site_id, keywords: unslug(keywords), type: 'keyword_search'} }),
  
  UrlParser.new(JQL, Proc.new { |site_id, keywords, location| {site_id: site_id, keywords: unslug(keywords), location: unslug(location), type: 'jql'} }),
  UrlParser.new(JLQ, Proc.new { |site_id, location, keywords| {site_id: site_id, keywords: unslug(keywords), location: unslug(location), type: 'jlq'} }),
  UrlParser.new(JQ, Proc.new { |site_id, keywords| {site_id: site_id, keywords: unslug(keywords), type: 'jq'} }),
  UrlParser.new(JL, Proc.new { |site_id, location| {site_id: site_id, location: unslug(location), type: 'jl'} }),
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
  PARSERS.each do |parser|
    if match = line.match(parser.regex)
      result = parser.block.call(match.captures)
      result = also_parse(result, line, SOURCE, :source)
      result = also_parse(result, line, ALERT_ID, :alert_id)
      return result.merge(url: line)
    end
  end
  raise RuntimeError, "cant parse line #{line}" 
end

def parse_file(file_name)
  result = []

  text = File.open(file_name).read
  text.each_line do |line|
    line = line.strip
    unless line.empty? 
      hash = parse_line(line)
      result << hash if hash
    end
  end

  result
end

results = parse_file(ARGV[0])
puts JSON.pretty_generate(results)