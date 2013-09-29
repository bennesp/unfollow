require 'yaml'
require 'timeout'

require 'rubygems'
require 'oauth'
require 'twitter'

@colors = {}

def load_colors
  if(@use_colors) then
    d "Using Colors"
    @colors = {:white=>"\e[0;37m", :red=>"\e[0;31m", :blue=>"\e[0;36m", :yellow=>"\e[0;33m"}
  else
    d "No Colors"
    @colors = {:white=>"", :red=>"", :blue=>"", :yellow=>""}
  end
end

def d s
  puts "\r#{@colors[:blue]}[D] "+s.to_s+"#{@colors[:white]}" if @verbose.to_i>2
end

def w s
  puts "\r#{@colors[:yellow]}[W] "+s.to_s+"#{@colors[:white]}" if @verbose.to_i>1
end

def e s
  puts "\r#{@colors[:red]}[E] "+s.to_s+"#{@colors[:white]}" if @verbose.to_i>0
end

# Impostazioni
def settings
  begin
    require 'settings'
    load_colors
    d "'settings.rb' loaded"
  rescue LoadError=>e
    w "'settings.rb' not found: asking user for creation"
    puts "This must be your first start, please, insert your consumer key:"
    @ck=gets.chomp
    puts "And your consumer secret key:"
    @cs=gets.chomp
    d "Got ck and cs. Saving..."
    File.open "settings.rb", "w" do |f|
      f.puts "@ck = \"#{@ck}\""
      f.puts "@cs = \"#{@cs}\""
      f.puts "@f = \".tokens\"\n\n@dataFile = \"data\"\n@cache = true\n@cache_time = 600\n@statsFile = \"stats.yaml\"\n\n@use_colors = true\n\n# 0=quite,1=errors,2=warnings,3=debugs\n@verbose = 3\n\n# change these with your whitelisted users\n@whitelist = [\"alecover\", \"marcobianchiweb\"]"
    end
    d "Settings saved."
    require "settings.rb"
    load_colors
    d "Settings loaded."
  end
end

def start
  @friends_ids = []
  @followers_ids = []
  @to_remove = []
  @unfollowers_ids = []
  if File.exist?@f then
    load_ot_os
  else
    auth_tokens
  end
end

def auth_tokens
  d "Tokens not found, Re-Authenticating..."
  consumer = OAuth::Consumer.new(@ck, @cs, {:site=>"https://twitter.com/", :scheme=>:header})
  request_token = consumer.get_request_token
  begin
    puts "Please, go to "+request_token.authorize_url+" and insert the Pin:"
    p=gets.chomp
    access_token = request_token.get_access_token(:oauth_verifier=>p)
  rescue OAuth::Unauthorized
    puts "PIN wrong. Please, insert the PIN from #{request_token.authorize_url} (or press CTRL+C to end"
    retry
  rescue Interrupt
    puts "Bye!"
    exit
  end

  @ot=access_token.token
  @os=access_token.secret
  save_tokens
  d "Authenticated"
end

# In progress, not working yet
def auth_base
  d "Authentication with user/pass"
  puts "Insert the user (@example):"
  u=gets.chomp
  puts "Insert the password. This will not be stored, saved or shared:"
  p=gets.chomp
  Twitter::Client.new(:username => u, :password => p)
end

def save_tokens
  d "Saving Tokens"
  oar = [@ot.to_s,@os.to_s]
  File.open @f, "w" do |f|
    f.puts YAML::dump(oar)
  end
  d "Token saved"
end

def load_ot_os
  d "Tokens found in "+@f
  oar = YAML.load_file(@f)
  @ot=oar[0]
  @os=oar[1]
  d "Loaded Oauth Token and Oauth Secret Token"
end

def config_twitter
  d "Configuring Twitter..."
  Twitter.configure do |config|
    config.consumer_key = @ck
    config.consumer_secret = @cs
    config.oauth_token = @ot
    config.oauth_token_secret = @os
  end
  d "Twitter Configured"
end

def last
  return "Last operation successed: "+@lastop.to_s
end

def get_friends_ids
  d "Getting friends ids..."
  c=-1
  begin
    c = Twitter.friend_ids(({:cursor=>c}) ? c!=-1 : nil)
    @lastop=Time.now
    @friends_ids = @friends_ids.concat c.all
  end while c.next_cursor!=0
  d "Got all the #{@friends_ids.length} Friends IDs"
end

def get_followers_ids
  d "Getting followers ids..."
  c=-1
  begin
    c = Twitter.follower_ids(({:cursor=>c}) ? c!=-1 : nil)
    @lastop=Time.now
    @followers_ids = @followers_ids.concat c.all
  end while c.next_cursor!=0
  d "Got all the #{@followers_ids.length} Followers IDs"
end

def load_friends_ids
  @friends_ids = YAML.load_file(@dataFile)[1][:friends]
  d "Loaded #{@friends_ids.length} friends from file"
end

def load_followers_ids
  @followers_ids = YAML.load_file(@dataFile)[1][:followers]
  d "Loaded #{@followers_ids.length} followers from file"
end

def load_old_data
  if File.exists?@dataFile then
    data = YAML.load_file(@dataFile)[1]
    @old_fo_n = data[:followers].length
    @old_fr_n = data[:friends].length
  else
    @old_fo_n = 0
    @old_fr_n = 0
  end
end

def time2ago t
  s=""
  if t>=86400 then
    s+=(t/86400).to_i.to_s+" days "
  end
  if t%86400>3600 then
    s+=((t%86400)/3600).to_i.to_s+" hours "
  end
  if (t%86400%3600)>60 then
    s+=((t%86400%3600)/60).to_i.to_s+" minutes "
  end
  if (t%86400%3600%60)!=0 then
    s+=(t%86400%3600%60).to_i.to_s+" seconds "
  end
  return s.chop
end

def check_cache
  if(@cache==false or File.exists?(@dataFile)==false) then
    d "Cache disabled or '#{@dataFile}' not found. Getting new data."
    get_friends_ids
    get_followers_ids
    return
  end
  date=YAML.load_file(@dataFile)[0]
  if ((Time.now-date)>@cache_time) then
    d "Cache copy of '#{@dataFile}' expired #{time2ago(Time.now-date)} ago"
    get_friends_ids
    get_followers_ids
  else
    load_friends_ids
    load_followers_ids
  end
end

def which_remove
  @friends_ids.each do |fid|
    if(@followers_ids.index(fid)==nil) then
      @to_remove << fid
    end
  end
  @to_remove.concat @unfollowers_ids
end

def get_users_from_ids ids
  temp = []
  ids.each_slice(100).each do |ar|
    temp = temp.concat Twitter.users(ar)
  end
  return temp
end

def name_of ar
  r=""
  ar.to_a.each do |u|
    r+=u.screen_name+","
  end
  return r.chop
end

def filter users
  d "Filtering #{users.length} with Verified Accounts..."
  # With Verified Account
  temp = []
  users.each do |t|
    if(t.verified==false) then
      temp << t
    end
  end
  d "Filtered #{users.length-temp.length} users beacuse verified"
  # With WhiteList
  d "Loading Whitelist..."
  if(@whitelist.length!=0) then
    d "Whitelist loaded with #{@whitelist.length} rules. Filtering with WhiteList..."
    tr=[]
    temp.each do |t|
      if @whitelist.index(t.screen_name)==nil
        tr<<t
      end
    end
    d "Filtered #{temp.length-tr.length} users because whitelisted"
    return tr
  else
    w "'whitelist' settings empty. avoiding it."
    return temp
  end
end

def remove
  which_remove
  
  tr=filter get_users_from_ids(@to_remove)
  puts "Attenzione, verranno unfollowati #{tr.length} utenti."
  puts name_of tr
  puts "Premere Invio per continuare, o CTRL+C per interrompere"
  gets
  d "Unfollowing #{tr.length} users..."
  Twitter.unfollow(tr)
  d "Done."
end

def track_unfollowers
  if @cache==false then
    w "Cannot track future unfollowers: cache disabled"
    return
  end
  if (File.exists?@dataFile)==false then
    w "Cannot track unfollowers: '#{@dataFile}' doesn't exist. Maybe first run?"
    return
  end
  if(@unfollowers_ids==nil) then @unfollowers_ids = [] end
  YAML.load_file(@dataFile)[1][:followers].each do |f|
    if @followers_ids.index(f)==nil then
      @unfollowers_ids << f
    end
  end
  d "Found #{@unfollowers_ids.length} unfollowers."
end

def save_data ar
  if(@cache) then
    File.open @dataFile, "w" do |fi|
      fi.puts YAML::dump ar
    end
    d "Info Saved in #{@dataFile}"
  else
    d "Info not saved, cache disabled in 'settings.rb'"
  end
end

def save_stats ar
  if(@stats) then
    File.open @statsFile, "r+" do |fi|
      fi.read
      fi.puts YAML::dump ar
    end
  end
end

def track_all
  track_unfollowers

  fo = @followers_ids.to_a
  fr = @friends_ids.to_a
  un = @unfollowers_ids.to_a
  
  save_data([Time.now, {:followers=>fo, :friends=>fr, :unfollowers=>un}])
  save_stats([Time.now, {:followers=>(fo.length-@old_fo_n), :friends=>(fr.length-@old_fr_n), :unfollowers=>un.length}])

  if un.length>0 then
    puts "Show names of #{un.length} unfollowers? [Yes/No]"
    g=gets.chomp.downcase
    if(g=="y" or g=="yes") then
      puts "(#{name_of get_users_from_ids(un)})"
    end
  end
end

begin
  begin
    settings
    start
    config_twitter
    load_old_data
    begin
      timeout(20) do
        check_cache
      end
    rescue Timeout::Error=>ex
      e "Timeout. Retrying..."
      retry
    end
    track_all
    remove
  rescue Twitter::Error::TooManyRequests=>ex
    e ex.message
    d "Sleeping for 20 seconds..."
    sleep 20
    retry
  rescue Twitter::Error::ClientError=>ex
    e ex.message
    d "Sleeping for 5 seconds..."
    sleep 5
    retry
  end
rescue Interrupt=>ex
  w "Pressed CTRL+C . Bye!"
  exit
end
