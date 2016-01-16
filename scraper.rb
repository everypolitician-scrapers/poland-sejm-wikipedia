#!/bin/env ruby
# encoding: utf-8

require 'colorize'
require 'mediawiki_api'
require 'nokogiri'
require 'open-uri'
require 'scraperwiki'

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
  ['','stycznia','lutego','marca','kwietnia','maja','czerwca','lipca','sierpnia','września','października','listopada','grudnia'].find_index(str) or raise "Unknown month #{str}"
end

def scrape_term(id, url)
  noko = noko_for(url)
  members = current_members(noko, url, id) + expired_members(noko, url, id)
  ScraperWiki.save_sqlite([:id, :term], members)
end

def area_for(noko, mem, termid)
  return unless mem
  area_table = noko.xpath('.//h2[contains(.,"wyborczych")]/following-sibling::table')[1]
  in_district = area_table.css(%Q!a[href*="#{mem.attr("href")}"]!)
  return if in_district.empty?
  district_tr = in_district.xpath('../../..') 
  id =  district_tr.xpath('td').first.text
  name = district_tr.xpath('.//preceding::h3[1]/span[@class="mw-headline"]').text
  return { id: nil, name: name } if id.to_s.empty? 
  return {
    id:   "%s-%s" % [id, termid],
    name: "%s %s" % [name, id]
  }
end

def current_members(noko, url, termid)
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
        id: mem.attr('title').downcase.gsub(/ /,'-'),
        name: mem.text,
        wikipedia__pl: mem.attr('title'),
        term: termid, 
        party: party,
        source: url,
      }

      if area = area_for(noko, mem, termid)
        data[:area]    = area[:name]
        data[:area_id] = area[:id]
      end

      # puts "#{data}".green
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

def expired_members(noko, url, termid)
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
      id: mem.attr('title').downcase.gsub(/ /,'-'),
      name: mem.text,
      wikipedia__pl: mem.attr('title'),
      party: @colors[color],
      term: termid, 
      end_date: tds[1].css('span').text,
      replaced: tds[-1].css('a/@title').text, 
      source: url,
    }

    replaced = tds[-1].css('a').first

    if area = area_for(noko, replaced, termid)
      data[:area]    = area[:name]
      data[:area_id] = area[:id]
    end

    # puts "#{data}".cyan
    members << data
  end
  members
end

{ 
  1 => 'https://pl.wikipedia.org/wiki/Pos%C5%82owie_na_Sejm_Rzeczypospolitej_Polskiej_I_kadencji',
  2 => 'https://pl.wikipedia.org/wiki/Pos%C5%82owie_na_Sejm_Rzeczypospolitej_Polskiej_II_kadencji',
  3 => 'https://pl.wikipedia.org/wiki/Pos%C5%82owie_na_Sejm_Rzeczypospolitej_Polskiej_III_kadencji',
  4 => 'https://pl.wikipedia.org/wiki/Pos%C5%82owie_na_Sejm_Rzeczypospolitej_Polskiej_IV_kadencji',
  5 => 'https://pl.wikipedia.org/wiki/Pos%C5%82owie_na_Sejm_Rzeczypospolitej_Polskiej_V_kadencji',
  6 => 'https://pl.wikipedia.org/wiki/Pos%C5%82owie_na_Sejm_Rzeczypospolitej_Polskiej_VI_kadencji',
  7 => 'https://pl.wikipedia.org/wiki/Pos%C5%82owie_na_Sejm_Rzeczypospolitej_Polskiej_VII_kadencji',
  8 => 'https://pl.wikipedia.org/wiki/Pos%C5%82owie_na_Sejm_Rzeczypospolitej_Polskiej_VIII_kadencji',
}.reverse_each do |id, url|
  puts id
  scrape_term(id, url)
end
