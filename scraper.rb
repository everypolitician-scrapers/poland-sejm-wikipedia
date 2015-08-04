#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

@colors = {}

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def month(str)
  ['','styczeń','lutego','marca','kwietnia','maja','czerwca','lipca','sierpnia','września','października','listopada','grudnia'].find_index(str) or raise "Unknown month #{str}"
end

def scrape_list(url)
  noko = noko_for(url)
  members = current_members(noko, url) + expired_members(noko, url)
  ScraperWiki.save_sqlite([:name, :term], members)
end


def current_members(noko, url)
  section = noko.xpath('.//h2[contains(.,"klubowa")]')
  table = section.xpath('following-sibling::table').first
  members = []
  table.xpath('tr[th]').each do |klub|
    party = klub.xpath('th').text.tidy
    color = klub.xpath('following-sibling::tr[1]/td').attr('style').text[/background:\s*#(\w+)/, 1]
    @colors[color] = party
    klub.xpath('following-sibling::tr[2]//li').each do |li|
      mem = li.css('a').first
      data = { 
        name: mem.text,
        wikipedia__pl: URI.join(url, URI.escape(mem.attr('href'))).to_s,
        term: 7, 
        party: party,
        source: url,
      }
      if not (citeref = li.css('sup a/@href').text).empty?
        note = noko.css(citeref).text rescue ''
        if note.match(/Ślubowała? (\d+)\s+(.*?)\s+(\d+)/)
          data[:start_date] = '%s-%02d-%02d' % [ $3, month($2.downcase), $1 ]
        end
      end
      members << data
    end
  end
  members
end

def expired_members(noko, url)
  section = noko.xpath('.//h3[contains(.,"mandat wygasł")]')
  table = section.xpath('following-sibling::table').first
  members = []
  color = nil
  table.xpath('tr[td]').each do |tr|
    tds = tr.css('td')
    if tds.first.text.empty?
      color = tds.shift.attr('style')[/background:\s*#(\w+)/, 1]
    end
    mem = tds[0].css('a').first
    data = { 
      name: mem.text,
      wikipedia__pl: URI.join(url, URI.escape(mem.attr('href'))).to_s,
      party: @colors[color],
      term: 7, 
      end_date: tds[1].css('span').text,
      replaced: tds[-1].css('a/@href').first.text, # TODO map to ID
      source: url,
    }
    members << data
  end
  members
end




scrape_list('https://pl.wikipedia.org/wiki/Pos%C5%82owie_na_Sejm_Rzeczypospolitej_Polskiej_VII_kadencji')
