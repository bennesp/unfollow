require 'yaml'

require 'rubygems'
require 'oauth'
require 'twitter'

# Impostazioni
def settings
  begin
    require 'settings'
    d "'settings.rb' loaded"
  rescue LoadError=>e
    w "'settings.rb' not found: asking user for creation"
    puts "This must be your first start, please, insert your consumer key:"
    @ck=gets.chomp
    puts "And your consumer secret key:"
    @cs=gets.chomp
    d "Got ck and cs. Saving..."
    File.open("settings.rb", "w") do |f|
      f.puts "@ck = \"#{@ck}\""
      f.puts "@cs = \"#{@cs}\""
      f.puts "@f = \".tokens\"\n@DEBUG = true\n@WARNINGS = true\n@ERRORS = true"
    end
    @f = ".tokens"
    @DEBUG = true
    @WARNINGS = true
    @ERRORS = true
    d "Saved."
  end
end

# Variabili gloabli
@friends_ids = []
@followers_ids = []
@to_remove = []
@colors = {:white=>"\e[0;37m", :red=>"\e[0;31m", :blue=>"\e[0;36m", :yellow=>"\e[0;33m"}
@lastop = Time.now

def start
  if File.exist?@f then
    load_ot_os
  else
    auth_tokens
  end
end

def d s
  puts "#{@colors[:blue]}[D] "+s.to_s+"#{@colors[:white]}" if @DEBUG
end

def w s
  puts "#{@colors[:yellow]}[W] "+s.to_s+"#{@colors[:white]}" if @WARNINGS or @DEBUG
end

def e s
  puts "#{@colors[:red]}[E] "+s.to_s+"#{@colors[:white]}" if @ERRORS or @WARNINGS or @DEBUG
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
  save
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

def save
  d "Saving Tokens"
  f = File.open @f, "w"
  f.puts YAML::dump @ot.to_s
  f.puts YAML::dump @os.to_s
  f.close
  d "Token saved"
end

def load_ot_os
  d "Tokens found in "+@f
  oar = []
  f = File.open(@f, "r").each do |o|
    oar << YAML::load(o)
  end
  @ot=oar[0]
  @os=oar[1]
  f.close
  d "Loaded Oauth Token and Oauth Secret Token"
end

def config
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
  File.open "friendsIDs", "w" do
    |file| file.puts YAML::dump @friends_ids
  end
  d "Info Saved"
end

def get_followers_ids
  d "Getting followers ids..."
  c=-1
  begin
    c = Twitter.follower_ids(({:cursor=>c}) ? c!=-1 : nil)
    @lastop=Time.now
    @followers_ids = @followers_ids.concat c.all
  end while c.next_cursor!=0
  d "Got all the #{@followers_ids.length} Followers IDs. Saving..."
  File.open "followersIDs", "w" do
    |file| file.puts YAML::dump @followers_ids
  end
  d "Info Saved"
end

def load_friends_ids
  File.open "friendsIDs", "r" do
    |file| @friends_ids = YAML::load(file.read)
  end
  d "Loaded #{@friends_ids.length} friends from file"
end

def check_friends
  if(File.exists?"friendsIDs")==false then
    get_friends_ids
  else
    load_friends_ids
  end
end

def load_followers_ids
  File.open "followersIDs", "r" do
    |file| @followers_ids = YAML::load(file.read)
  end
  d "Loaded #{@followers_ids.length} followers from file"
end

def check_followers
  if(File.exists?"followersIDs")==false then
    get_followers_ids
  else
    load_followers_ids
  end
end

def which_remove
  @friends_ids.each do |fid|
    if(@followers_ids.index(fid)==nil) then
      @to_remove << fid
    end
  end
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
  if(File.exists?"whitelist") then
    whitelist = YAML::load(File.open("whitelist", "r").read)
    d "Whitelist loaded with #{whitelist.length} rules. Filtering with WhiteList..."
    tr=[]
    temp.each do |t|
      if whitelist.index(t.screen_name)==nil
        tr<<t
      end
    end
    d "Filtered #{temp.length-tr.length} users because whitelisted"
    return tr
  else
    w "'whitelist' file not found. avoiding it."
    return temp
  end
end

def remove
  which_remove
  temp = []
  @to_remove.each_slice(100).each do |ar|
    temp = temp.concat Twitter.users(ar)
  end

  tr=filter temp
  puts "Attenzione, verranno unfollowati #{tr.length} utenti."
  puts name_of tr
  puts "Premere Invio per continuare, o CTRL+C per interrompere"
  gets
  d "Unfollowing #{tr.length} users..."
  Twitter.unfollow(tr)
  d "Done."
end

begin
  settings
  start
  config
  check_friends
  check_followers
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
rescue Interrupt=>ex
  w "Pressed CTRL+C . Bye!"
  exit
end

