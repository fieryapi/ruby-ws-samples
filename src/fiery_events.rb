require 'rubygems'

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __FILE__)
require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])


require 'eventmachine'
require 'faye/websocket'
require 'json'
require 'rest-client'


## *****************************************************************************
## configuration section
## *****************************************************************************

# set the host name as fiery server name or ip address
$hostname = 'the_server_name_or_ip_address'

# set the key to access Fiery API
$api_key = 'the_api_key'

# set the username to login to the fiery server
$username = 'the_username'

# set the password to login to the fiery server
$password = 'the_password'

# websocket object
$ws = nil


# login to the fiery server
def login
  login_json = {
    :username => $username,
    :password => $password,
    :accessrights => $api_key
  }

  client = RestClient::Resource.new("https://#{$hostname}/live/api/v2/", :headers => {}, :verify_ssl => OpenSSL::SSL::VERIFY_NONE)

  request = login_json.to_json
  response = client['login'].post(request, {:content_type => 'application/json'})

  client.options[:headers][:cookies] = response.cookies

  puts
  puts 'Login'
  puts response
  client
end

# logout from the fiery server
def logout(client)
  response = client['logout'].post(nil)

  client.options[:headers][:cookies] = response.cookies

  puts
  puts 'Logout'
  puts response
end

# receive events from fiery server
def receive_fiery_events
  # login to fiery server
  client = login

  # get the session cookies
  cookies = client.options[:headers][:cookies]

  # add cookie to the custom header for websocket client
  custom_headers = {'cookie' => cookies.to_s.delete("\"{>}")}

  # set the websocket server address
  server_address = "wss://#{$hostname}/live/api/v2/events"

  # establish websocket connection and receive fiery events
  run_websocket(server_address, custom_headers)

  # logout from fiery server and close websocket connection
  logout(client)
end

# set filters to receive only fiery status change events
def receive_fiery_status_change_events
  puts
  puts "Scenario: Receive only Fiery status change events"
  puts "Press <Enter> when you want to run next scenario"

  # ignore all events except device
  $ws.send(
  {
    :jsonrpc => "2.0",
    :method => :ignore,
    :params => [:accounting, :job, :jobprogress, :preset, :property, :queue],
    :id => 1
  }.to_json)

  # receive device events
  $ws.send(
  {
    :jsonrpc => "2.0",
    :method => :receive,
    :params => [:device],
    :id => 2
  }.to_json)

  gets
end

# set filters to receive only job is printing? events
def receive_job_is_printing_events
  puts
  puts "Scenario: Receive only job is printing? events"
  puts "Press <Enter> when you want to run next scenario"

  # ignore all events except job events
  $ws.send(
  {
    :jsonrpc => "2.0",
    :method => :ignore,
    :params => [:accounting, :device, :jobprogress, :preset, :property, :queue],
    :id => 1
  }.to_json)

  # receive job events
  $ws.send(
  {
    :jsonrpc => "2.0",
    :method => :receive,
    :params => [:job],
    :id => 2
  }.to_json)

  # receive job events only if they contain <is printing?> key in the <attributes>
  $ws.send(
  {
    :jsonrpc => "2.0",
    :method  => :filter,
    :params =>
    {
      :eventKind => :job,
      :mode => :add,
      :attr => { :attributes => ["is printing?"] }
    },
    :id => 3
  }.to_json)

  gets
end

# set filters in batch mode to receive only job is printing? events
def receive_job_is_printing_events_in_batch_mode
  puts
  puts "Scenario: Receive only job is printing? events in batch mode"
  puts "Press <Enter> when you want to run next scenario"

  $ws.send(
  [
    # ignore all events except job events
    {
      :jsonrpc => "2.0",
      :method => :ignore,
      :params => [:accounting, :device, :jobprogress, :preset, :property, :queue],
      :id => 1
    },

    # receive job events
    {
      :jsonrpc => "2.0",
      :method => :receive,
      :params => [:job],
      :id => 2
    },

    # receive job events only if they contain <is printing?> key in the <attributes>
    {
      :jsonrpc => "2.0",
      :method  => :filter,
      :params =>
      {
        :eventKind => :job,
        :mode => :add,
        :attr => { :attributes => ["is printing?"] }
      },
      :id => 3
    }
  ].to_json)

  gets
end

# open websocket connection, set event listeners and receive fiery events
def run_websocket(server_address, custom_headers)
  EM.run {
    $ws = Faye::WebSocket::Client.new(server_address, nil, :headers => custom_headers)

    $ws.on :open do |event|
      puts "new websocket connection is opened"
      EM.defer(
        proc do
          receive_fiery_status_change_events
          receive_job_is_printing_events
          receive_job_is_printing_events_in_batch_mode
          $ws.close
        end
      )
    end

    $ws.on :message do |event|
      puts event.data.to_json
    end

    $ws.on :error do |event|
      puts event.data.to_json
    end

    $ws.on :close do |event|
      puts "websocket connection closed: #{event.code} #{event.reason}"
      EM::stop_event_loop
    end
  }
end

receive_fiery_events