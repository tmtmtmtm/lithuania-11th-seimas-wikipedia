#!/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'pry'
require 'scraped'
require 'wikidata_ids_decorator'

require_relative 'lib/remove_notes'
require_relative 'lib/unspan_all_tables'

class ExistingMembers
  def initialize(pathname)
    @pathname = pathname
  end

  def single_exact_match_for(name)
    found = by_name[name] or return
    ids = found.map(&:last).uniq
    unless ids.count == 1
      warn "More than one match for #{name}"
      return
    end
    ids.first
  end

  private

  attr_reader :pathname

  def csv
    @csv ||= CSV.parse(pathname.read)
  end

  def by_name
    csv.group_by(&:first)
  end
end

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

  # These rely on no-one having both a From and Until. If this wasn't
  # true we'd need to be more precise in our parsing.
  field :start_date do
    return unless notes.include? 'From '
    Date.parse(notes)
  end

  field :end_date do
    return unless notes.include? 'Until '
    Date.parse(notes)
  end

  private

  def tds
    noko.css('td')
  end

  def notes
    tds[3].text.tidy
  end
end

url = URI.encode 'https://en.wikipedia.org/wiki/Eleventh_Seimas_of_Lithuania'
data = Scraped::Scraper.new(url => MembersPage).scraper.members

# Generated from:
#   wd sparql all-members.sparql | jq -r '.[] | [.item.label, .item.value] | @csv' | sort | uniq
all_members_csv = Pathname.new('all-members.csv')
if all_members_csv.exist?
  lookup = ExistingMembers.new(all_members_csv)
  data.each { |mem| mem[:id] ||= lookup.single_exact_match_for(mem[:name]) }
end

header = data.first.keys.to_csv
rows = data.map { |row| row.values.to_csv }
puts header + rows.join
