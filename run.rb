# encoding: utf-8
require 'rubygems'
require 'bundler/setup'
require 'json'
require 'awesome_print'
require 'pry'
require 'rest_client'
require 'time'
require 'date'
require 'active_support/all'
require 'dotenv/load'
require 'csv'
require 'uri'
require 'vcr'

class Util

  def self.configure
    Time.zone = ENV['TZ'] || 'Brasilia'
    VCR.configure do |c|
      c.cassette_library_dir = ENV['CACHE_DIR'] || 'cache'
      c.hook_into :webmock # or :fakeweb
      c.allow_http_connections_when_no_cassette = true
    end    
  end

  def self.get(*params)
    log "  -> Connecting to #{params.first}".blue
    @body = RestClient.get *params
  end

  def self.post(*params)
    log "  -> Connecting to #{params.first}".blue
    @body = RestClient.post *params
  end

  def self.alert(codigo, message = nil)
    puts ('*' * 120).white
    print "#{(' ' * 4)}#{codigo.yellow}"
    print " - #{message.red}" unless message.nil?
    print "\n"
    puts ('*' * 120).white
  end

  def self.log(params = {})
    @complete_log ||= []
    params = {message: params} if params.is_a? String
    puts ('*' * 120).white if params[:divider]
    @complete_log << "#{('*' * 120)}\n" if params[:divider]
    puts params[:message] if params[:message]
    @complete_log << "#{params[:message]}\n".gsub(/\[1;3[0-9]?m/,"").gsub("\[0m","") if params[:message]
    # if(params[:push] and params[:message])
    #   Pushover.notification(message: params[:message], title: 'Script Ampliar')
    # end
  end

  def self.confirm(params = {})
    print "\n#{params[:message]} [Yn] "
    return STDIN.gets.chomp.downcase != 'n'
  end

  def self.complete_log
    return if @complete_log.nil?
    @complete_log.join("\n")
  end

  def self.date(v)
    dia, mes, ano = v.split("/")
    return nil if ano.nil? or mes.nil? or dia.nil?
    Time.new(ano, mes, dia).to_date
  end

  def self.number(v)
    v.gsub('.','').gsub(',','.').to_f
  end
end

class Subscriber
  attr :row
  attr :attributes

  def initialize(row, columns)
    @attributes = {}
    @row = row
    columns.each_with_index do |column, i|
      @attributes[column] = @row[i]
    end
  end

end


class Updater
  class << self
    def run
      get_all_contacts
      @i = 0
      CSV.foreach("contacts.csv") do |row|
        if(@i == 0)
          @columns = row 
        else
          subscriber = Subscriber.new(row, @columns)
          Util.log("Processing row #{@i}: #{subscriber.attributes['email']}...".white)
          if subscriber.attributes['tags'].blank?
            Util.log("  -> Skipping... Subscriber doesn't have tags to update")
            next
          end
          contact = get_contact(subscriber.attributes['email'])
          email = contact['fields']['core']['email']['value']
          Util.log("  -> Returned #{email}...")
          if !contact['tags'].blank?
            Util.log("  -> Skipping... Contact already has tags (#{contact['tags']})")
            next
          end
          if email != subscriber.attributes['email']
            Util.log("  -> Email address different from Mautic search result".yellow)
            next
          end
          update_tags(contact['id'], subscriber.attributes['tags'])
        end
        @i = @i+1
      end
    end

    private

      def get_total_contacts
        ret = VCR.use_cassette('total_contacts') do
          RestClient.get "#{ENV['MAUTIC_URL']}/api/contacts", {Authorization: "Basic #{ENV['MAUTIC_TOKEN']}"}
        end
        @total = JSON.parse(ret)['total'].to_i
      end

      def get_contacts(per_page, start)
        ret = VCR.use_cassette("contacts_#{per_page}_#{start}") do
          RestClient.get "#{ENV['MAUTIC_URL']}/api/contacts?limit=#{per_page}&start=#{start}", {Authorization: "Basic #{ENV['MAUTIC_TOKEN']}"}
        end
        @contacts = JSON.parse(ret)['contacts']
      end

      def get_all_contacts
        total = get_total_contacts
        @all_contacts = {}
        per_page = 500
        pages = (total.to_f/per_page.to_f).ceil
        Util.log("Getting all contacts. Total of #{total} in #{pages} pages of #{per_page} contacts per page".white)
        pages.times do |i|
          Util.log("  Processing page #{i+1}")
          start = per_page*i
          @all_contacts.merge!(get_contacts(per_page, start))
        end
        if @all_contacts.size != total
          Util.log('Could not get all contacts'.red)
          exit
        end
      end

      def get_contact(email)
        return if email.blank?
        if @contacts_by_email.blank?
          @contacts_by_email = {}
          @all_contacts.each do |contact|
            contact_email = contact[1]['fields']['core']['email']['value']
            unless contact_email.blank?
              @contacts_by_email[contact_email] = contact[1]
            end
          end
        end
        @contacts_by_email[email]
      end

      def update_tags(contact_id, tags)
        Util.log("  -> Updating contact #{contact_id} with tags #{tags}...")
        ret = VCR.use_cassette("patch_contact/#{contact_id}") do
          RestClient.patch "#{ENV['MAUTIC_URL']}/api/contacts/#{contact_id}/edit", {'tags' => tags}, {Authorization: "Basic #{ENV['MAUTIC_TOKEN']}"}
        end
        if JSON.parse(ret)['contact']['id'] == contact_id
          Util.log("  -> Contact Updated!".green)
        else
          Util.log("  -> Fail to update contact".red)
          exit
        end
      end
  end
end

Util.configure