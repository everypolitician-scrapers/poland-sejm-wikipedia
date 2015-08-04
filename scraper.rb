#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def month(str)
  idx = ['','styczeń','lutego','marca','kwietnia','maja','czerwca','lipca','sierpnia','września','października','listopada','grudnia'].find_index(str)
  warn "Need month for #{str}".magenta unless idx
  idx
end

def scrape_list(url)
  noko = noko_for(url)

  section = noko.xpath('.//h2[contains(.,"klubowa")]')
  table = section.xpath('following-sibling::table').first

  table.xpath('tr[th]').each do |klub|
    party = klub.xpath('th').text.tidy
    color = klub.xpath('following-sibling::tr[1]/td').attr('style').text[/background:\s*#(\w+)/, 1]
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
      ScraperWiki.save_sqlite([:id, :term], data)
    end
  end
end

scrape_list('https://pl.wikipedia.org/wiki/Pos%C5%82owie_na_Sejm_Rzeczypospolitej_Polskiej_VII_kadencji')
