require "rubygems"
require "bundler/setup"
require 'sinatra/base'
require "erb"
require "yaml"
require 'kyotocabinet'
require 'json'
include KyotoCabinet

class Day
  NUMBER_OF_HOURS = 14 
  attr_accessor :date , :start_hour , :hours, :tasks, :notes, :hours_worked
  
  def initialize(date, start_hour)
    self.date = date
    self.start_hour = start_hour
    self.hours = set_hours
    self.tasks = []
    self.notes = ""
  end

  def hours_worked
    total = 0
    hours.each do |hour|
      ['fifteen' , 'thirty' , 'fortyfive' , 'sixty'].each do |min|
        total = total +1 if hour.send(min)
      end
    end
    (total * 15) / 60
  end

  def description
    tasks.join(" / ")
  end

  def set_hour_text(hour_index, minute_block, value)
    set_hour(hour_index, minute_block , value)
  end
  
  def get_hour_text(hour_index, minute_block)
    hour = hours[hour_index]
    hour.send("#{minute_block}_text") unless hour.nil?
  end

  def mark_hour(hour_index , minute_block, value)
    set_hour hour_index , minute_block , value
  end
 
  def get_hour(hour_index, minute_block)
    hour = hours[hour_index]
    hour.send(minute_block) unless hour.nil?
  end
  
  def date_key
    date.strftime("%d%m%Y")
  end

  def set_task(index, value)
    self.tasks[index.to_i] = value
  end

  private

  def set_hour(hour_index , minute_block, value)
    return if hour_index.nil?
    hour = hours[hour_index.to_i]
    
    unless hour.nil?
      if value == true || value == false
        hour.send("set_#{minute_block}", value)
      else
        #Must be text
        hour.send("set_#{minute_block}_text", value)
      end
    end
  end

 def set_hours
    h = []
    (0..NUMBER_OF_HOURS).each { h << Hour.new}
    h
  end
  

end


class Hour
  attr_accessor :fifteen, :thirty, :fortyfive, :sixty, :fifteen_text , :thirty_text, :fortyfive_text, :sixty_text


  def initialize
    self.fifteen = false
    self.thirty = false
    self.fortyfive = false
    self.sixty = false
    # Value
    self.fifteen_text = ''
    self.thirty_text = ''
    self.fortyfive_text = ''
    self.sixty_text = ''

  end
  
  # Need method calls so we can use .send
  def set_fifteen(value)
    self.fifteen = value
  end
  def set_thirty(value)
    self.thirty = value
  end
  def set_fortyfive(value)
    self.fortyfive = value
  end
  def set_sixty(value)
    self.sixty = value
  end
  
  def set_fifteen_text(value)
    self.fifteen_text = value
  end
  def set_thirty_text(value)
    self.thirty_text = value
  end
  def set_fortyfive_text(value)
    self.fortyfive_text = value
  end
  def set_sixty_text(value)
    self.sixty_text = value
  end


end

# Sinatra methods

class TaskPlanner < Sinatra::Base
  set :sessions, true 
  set :static, true
  set :root, File.dirname(__FILE__)
  set :public, 'public'

  configure :production, :development do
    enable :logging
  end

  #Database
  @@db = DB::new

  # open the database
  unless @@db.open('tplandb.kch', DB::OWRITER | DB::OCREATE)
    STDERR.printf("open error: %s\n", @@db.error)
  end

  get '/' do
    erb :index
  end
  
  post '/save' do
    #Lookup object
    @day =  @@db.get params[:day]
    @day = YAML::load(@day) if @day
    values = params[:id].split("_")
   
    if params[:hour]
      @day.set_hour_text values.first, values.last, params[:value]
    elsif params[:mark]
      val = params[:mark]
      val = true if val == 'true'
      val = false if val == 'false'
      @day.mark_hour values.first, values.last, val
    elsif params[:start_hour]
      @day.start_hour = params[:value]
    elsif params[:notes]
      ary = params[:value].split("\n")
      notes = ''
      ary.each do |s|
        notes << "<p>#{s}</p>"
      end
      @day.notes = notes
    else
      @day.set_task(values.last , params[:value])
    end
    @@db.set( @day.date_key, @day.to_yaml)
    params[:value]
  end

  get '/plan/:day/:month/:year' do
    if params[:day] == 'today'
      @date = Time.now
    elsif !params[:day].nil? && !params[:month].nil? && !params[:year].nil?
      @date = Date.parse("#{params[:month]}/#{params[:day]}/#{params[:year]}")
    end

    #Find in the db first
    value = @@db.get(date_key(@date))
    if value
      @day = YAML::load(value)
    else
      #Store it
      @day = Day.new @date , 9
      @@db.set(date_key(@date), @day.to_yaml)
    end
    erb :plan
  end
 
  get '/today' do
    time =Time.now
    redirect to "/plan/#{time.day}/#{time.month}/#{time.year}"
  end

  get '/yesterday' do
    time =Time.now
    redirect to "/plan/#{(time.day) -1}/#{time.month}/#{time.year}"
  end


  get '/export/:month/:year' do
    @records = []
    (01..31).each do |day|

      key = "#{day}#{params[:month]}#{params[:year]}"
      value = @@db.get(key)
      @records << YAML::load(value) if value
    end
    erb :export
  end
  
  private
  def date_key(date)
    date.strftime("%d%m%Y")
  end
end
