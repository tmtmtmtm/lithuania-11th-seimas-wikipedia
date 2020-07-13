#!/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'pry'
require 'scraped'
require 'wikidata_ids_decorator'

require_relative 'lib/remove_notes'
require_relative 'lib/unspan_all_tables'

class MembersPage < Scraped::HTML
  decorator RemoveNotes
  decorator WikidataIdsDecorator::Links
  decorator UnspanAllTables

  field :members do
    members_list.xpath('.//tr[td]').map { |td| fragment(td => MemberItem).to_h }
  end

  private

  def members_list
    noko.css('#Members').xpath('.//following::table').first
  end
end


class MemberItem < Scraped::HTML
  field :id do
    tds[0].css('a/@wikidata').map(&:text).first
  end

  field :name do
    tds[0].css('a').map(&:text).map(&:tidy).first
  end

  field :party do
    tds[2].css('a/@wikidata').map(&:text).first
  end

  field :partyLabel do
    tds[2].css('a').map(&:text).map(&:tidy).first
  end

  private

  def tds
    noko.css('td')
  end
end

url = URI.encode 'https://en.wikipedia.org/wiki/Eleventh_Seimas_of_Lithuania'
data = Scraped::Scraper.new(url => MembersPage).scraper.members

header = data.first.keys.to_csv
rows = data.map { |row| row.values.to_csv }
puts header + rows.join
