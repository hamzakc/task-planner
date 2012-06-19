require "rubygems"
require "bundler/setup"
require "innate"
require "erb"
require "yaml"
require 'kyotocabinet'
require 'json'
include KyotoCabinet

class Day
  NUMBER_OF_HOURS = 14 
  attr_accessor :date , :start_hour , :hours, :tasks, :notes
  
  def initialize(date, start_hour)
    self.date = date
    self.start_hour = start_hour
    self.hours = set_hours
    self.tasks = []
    self.notes = ""
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

# Innate method

class TaskPlanner
  Innate.node '/'
  @logger = Logger.new($stdout)
  provide :html, :engine => :ERB
  layout('default') {|name , wish| wish = 'html'}
  
  #Database
  @@db = DB::new

  # open the database
  unless @@db.open('tplandb.kch', DB::OWRITER | DB::OCREATE)
    STDERR.printf("open error: %s\n", @@db.error)
  end

  def index
  end
  
  def save
    #Lookup object
    @day =  @@db.get request[:day]
    @day = YAML::load(@day) if @day
    values = request[:id].split("_")
   
    if request[:hour]
      @day.set_hour_text values.first, values.last, request[:value]
    elsif request[:mark]
      val = request[:mark]
      val = true if val == 'true'
      val = false if val == 'false'
      @day.mark_hour values.first, values.last, val
    elsif request[:start_hour]
      @day.start_hour = request[:value]
    elsif request[:notes]
      ary = request[:value].split("\n")
      notes = ''
      ary.each do |s|
        notes << "<p>#{s}</p>"
      end
      @day.notes = notes
    else
      @day.set_task(values.last , request[:value])
    end
    @@db.set( @day.date_key, @day.to_yaml)
    request[:value]
  end

  def plan(day, month=nil, year=nil)
    if day == 'today'
      @date = Time.now
    elsif !day.nil? && !month.nil? && !year.nil?
      @date = Date.parse("#{month}/#{day}/#{year}")
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

  end
  
  private

  def date_key(date)
    date.strftime("%d%m%Y")
  end

  
end

# Start web framework
Innate.start
