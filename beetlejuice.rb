#!/usr/bin/env ruby

require 'bugsnag/api'
require 'optparse'
require 'pry'

default_keys = 'app.releaseStage,metaData,received_at'
options = Struct.new(:count, :keys, :output, :token, :url).new
OptionParser.new do |opts|
  opts.banner = "
    DESCRIPTION

      Beetlejuice: extracts the juicy bits out of Bugsnag

    USAGE

      ./beetlejuice.rb [options] url

    FLAGS
    "

  opts.on('-cCOUNT', '--count=COUNT', 'Amount of events to be fetched (default: 500)') do |c|
    options[:count] = c
  end

  opts.on(
    '-kKEYS', '--keys=KEYS', "Paths to values of interest, comma separated
                                      e.g.: - app.releaseStage,context,breadcrumbs.metaData.name
                                            - all (for all keys, payload may be huge. Try it once with `-c 1` to see the payload's shape and which keys are available)
                                            - defaults to #{default_keys}"
  ) do |k|
    options[:keys] = k
  end

  opts.on('-oOUTPUT', '--output=OUTPUT', 'Name of output file (default: output.json)') do |o|
    options[:output] = o
  end

  opts.on('-tTOKEN', '--set-token=TOKEN', 'Personal Bugsnag token (required once)') do |t|
    options[:token] = t
  end
end.parse!

options[:count] = (options[:count] || 500).to_i
options[:keys] = (options[:keys] || default_keys).split(',')
options[:output] = options[:output] || 'output.json'
options.url = ARGV[0]

class Beetlejuice
  def self.start(options:)
    if options.token
      File.write('.token', options.token)
      puts 'Token saved in .token, all set!'
      return
    end

    auth_token = File.exist?('.token') && File.read('.token')

    new(auth_token: auth_token, options: options).start
  end

  private_class_method :new

  def initialize(auth_token:, options:)
    @client = Bugsnag::Api::Client.new(auth_token: auth_token)
    @options = options
  end

  def start
    m = /https:\/\/app.bugsnag.com\/([^\/]*)\/([^\/]*)\/errors\/([^?]*)/.match(@options.url).to_a
    _, organization_slug, project_slug, error_id = m

    org = @client.organizations.find { |o| o.slug == organization_slug }

    @project = @client.projects(org.id).find { |p| p.slug == project_slug }

    @events = @client.error_events(@project.id, error_id, full_reports: true)
    @last_response = @client.last_response
    get_events

    write_to_disk
  rescue Bugsnag::Api::Unauthorized => e
    puts 'Authorization token incorrect.
          Go to Bugsnag > Click on your avatar > Settings > Personal auth tokens
          Generate a token and run:
          ./beetlejuice.rb --set-token=your-token
       '
  end

  def get_events
    until @last_response.rels[:next].nil? || @events.count >= @options.count
      @last_response = @last_response.rels[:next].get
      @events.concat @last_response.data

      print "Fetched #{[@events.count, @options.count].min}/#{@options.count} events\r"
    end
    puts
  rescue Bugsnag::Api::RateLimitExceeded => e
    puts
    puts 'Bugsnag::Api::RateLimitExceeded while getting events list'
    wait_time_total = 60
    puts "Waiting #{wait_time} seconds"

    progress_bar_length = 30
    wait_time = wait_time_total / progress_bar_length

    (1..progress_bar_length).each do |t|
      sleep wait_time
      print "[#{'=' * t}#{'.' * (progress_bar_length - t)}]\r"
    end
    puts

    get_events
  end

  def write_to_disk
    puts "Saving events to #{@options.output}"
    puts "Filtered to only keep the keys: #{@options.keys.join(',')}"
    File.write(@options.output, "[#{@events.first(@options.count).map { |evt| extract_event_data(keys: @options.keys, event: evt.to_h) }.map(&:to_json).join(',')}]")
  end

  def extract_event_data(keys:, event:)
    if keys.length == 1 && keys[0] == 'all'
      event
    else
      result = {}
      keys.each do |path|
        path_keys = path.split('.')
        obj = event.dup
        path_keys.each do |k|
          if obj.is_a?(Array)
            obj = obj.map { |o| o[k.to_sym] }
          else
            obj = obj[k.to_sym]
          end
        end
        result[path] = obj
      end
      result
    end
  end
end

Beetlejuice.start(options: options)
