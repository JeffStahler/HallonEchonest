# encoding: utf-8
require 'hallon'
require 'bundler/setup'
require 'base64'
require 'sinatra'
require 'addressable/uri'
require 'json'
require 'gon-sinatra'
require 'sinatra/reloader' if development?


Sinatra::register Gon::Sinatra

unless "".respond_to?(:try)
  class Object
    alias_method :try, :send
  end

  class NilClass
    def try(*)
    end
  end
end

class Track_with_echonest_and_lastfm_data < Hallon::Track
attr_accessor :artist_hotttnesss, :artist_familiarity, :danceability, :energy, :tempo
  
  def fetch_properties(json_from_echo_nest)
    json_from_echo_nest['response']['songs']
  end

end



class ConfigurationError < StandardError
end

def config_env(varname)
  ENV.fetch(varname) do
    raise ConfigurationError, "Missing ENV['#{varname}']."
  end
end


class Songkick
  
  ROOT_URL = 'http://api.songkick.com/api/3.0/'
  API_PARAM = 'apikey=UokXlLzqCN1zhOWe'
  def self.get_loc_id(city)
    city = URI.escape(city)
    url = "#{ROOT_URL}search/locations.json?query=#{city}&#{API_PARAM}" 
    json = JSON.parse(RestClient.get(url))
    json['resultsPage']['results']['location'][0]['metroArea']['id']  
  end

  def self.venue_seach(query)
    query = URI.escape(query)
    url = "#{ROOT_URL}search/venues.json?query=#{query}&#{API_PARAM}"
    json = JSON.parse(RestClient.get(url))
    json['resultsPage']['results']['venue']

  end


  def self.get_venue_events(query)
    venues = self.venue_seach(query)
    venue_id = venues[0]['id']
    url = "#{ROOT_URL}venues/#{venue_id}/calendar.json?#{API_PARAM}"
    json = JSON.parse(RestClient.get(url))
    json['resultsPage']['results']['event']  

  end

  def self.get_metro_calendar_using_loc_id(loc_id)
    url = "#{ROOT_URL}metro_areas/#{loc_id}/calendar.json?#{API_PARAM}"  
    json = JSON.parse(RestClient.get(url))
    json['resultsPage']['results']['event']  
  end

  def self.get_metro_calendar(city)
    loc_id = self.get_loc_id(city)
    metro_calendar = self.get_metro_calendar_using_loc_id(loc_id)
  end

  def self.get_events_by_city_and_dates(city, min_date, max_date)
    loc_id = self.get_loc_id(city)
    url = "#{ROOT_URL}events.json?location=sk:#{loc_id}&min_date=#{min_date}&max_date=#{max_date}&#{API_PARAM}"
    json = JSON.parse(RestClient.get(url))
    json['resultsPage']['results']['event'] 
  end 
end


configure do
  $hallon ||= begin
    require 'hallon'
    Hallon.load_timeout = 0

    appkey = Base64.decode64(config_env('HALLON_APPKEY'))
    Hallon::Session.initialize(appkey)
    #@player = Hallon::Player.new(Hallon::OpenAL)

  end

  set :hallon, $hallon

  # Allow iframing
  disable :protection
  # Only one request at a time
  enable :lock
end

helpers do
  def hallon
    Hallon::Session.instance
  end

  def link_to(text, object = text)
    link = object
    link = link.to_link if link.respond_to?(:to_link)
    href = link.try(:to_str)
    type = link.try(:type)
    %Q{<a class="#{type}" href="/#{object.to_str}">#{text}</a>}
  end

  def image_to(image_link)
    link_to %Q{<img src="/#{image_link.to_str}" class="#{image_link.type}">}, image_link
  end

  def logged_in_text
    if hallon.logged_in?
      user = hallon.user.load
      "logged in as #{link_to user.name, user}"
    else
      "not logged in"
    end
  end
end

at_exit do
  if Hallon::Session.instance?
    hallon = Hallon::Session.instance
    hallon.logout!
  end
end

def uri_for(type)
  lambda do |uri|
    uri = uri.sub(%r{\A/}, '')
    return unless Hallon::Link.valid?(uri)
    return unless Hallon::Link.new(uri).type == type
    Hallon::URI.match(uri)
  end.tap do |matcher|
    matcher.singleton_class.send(:alias_method, :match, :call)
  end
end

def get_echo_nest_data(track_uri)
track_uri = track_uri.gsub("spotify","spotify-WW")
  url = "http://developer.echonest.com/api/v4/song/profile?api_key=WYPYQRU4DH3HWKZUI&format=json&track_id=#{track_uri}&bucket=audio_summary&bucket=artist_familiarity&bucket=artist_hotttnesss"
json = JSON.parse(RestClient.get(url))
json['response']['songs'][0]

end


def get_echo_nest_id(track)
track_uri = track.to_link.to_uri
track_uri = track_uri.gsub("spotify","spotify-WW")

end


def get_echo_nest_data_for_tracks(tracks)
uri = Addressable::URI.parse("http://developer.echonest.com/api/v4/song/profile")
query_array = [["api_key", "WYPYQRU4DH3HWKZUI"], ["format", "json"] , ["bucket" "audio_summary"], ["bucket", "artist_familiarity"] , ["bucket" "artist_hotttnesss"]]


tracks.each do |track|
  track_uri = "#{track.to_link.to_uri}"
  track_uri = track_uri.gsub("spotify","spotify-WW")
  query_array << ["track_id", track_uri]  
end

uri.query_values = query_array
json = JSON.parse(RestClient.get(uri.to_str))
end




error Hallon::TimeoutError do
  status 504
  body "Hallon timed out."
end

before do
  unless hallon.logged_in?
    hallon.login!(config_env('HALLON_USERNAME'), config_env('HALLON_PASSWORD'))
  end
end

get '/' do
  @links = [
    Hallon::Link.new("spotify:track:4d8EFwexIj2rtX4fIT2l8Q"),
    Hallon::Link.new("spotify:artist:6aZyMrc4doVtZyKNilOmwu"),
    Hallon::Link.new("spotify:album:6cBZCIlOJCDC1Eh54aJDme"),
    Hallon::Link.new("spotify:user:burgestrand"),
    Hallon::Link.new("spotify:user:burgestrand:playlist:5BwQBlDoZVoNnDItvO2IUb")
  ]

  erb :index
end

get '/redirect_to' do
  href = params[:spotify_uri] if Hallon::Link.valid?(params[:spotify_uri])
  redirect to("/#{href}"), :see_other
end

get uri_for(:profile) do |user|
  @user = Hallon::User.new(user).load
  @starred = @user.starred.load
  @starred_tracks = @starred.tracks[0, 20].map(&:load)
  @playlists = @user.published.contents.select { |x| x.is_a?(Hallon::Playlist) }
  @playlists.each(&:load)
  erb :user
end

get uri_for(:track) do |track|
  @track  = Hallon::Track.new(track).load
  @artist = @track.artist.load
  @album  = @track.album.load
  @length = Time.at(@track.duration).gmtime.strftime("%M:%S")
  erb :track
end

get uri_for(:artist) do |artist|
  @artist    = Hallon::Artist.new(artist).load
  @browse    = @artist.browse.load
  @portraits = @browse.portrait_links.to_a
  @portrait  = @portraits.shift
  @tracks    = @browse.tracks[0, 20].map(&:load)
  @similar_artists = @browse.similar_artists.to_a
  @similar_artists.each(&:load)
  erb :artist
end

get uri_for(:album) do |album|
  @album  = Hallon::Album.new(album).load
  @browse = @album.browse.load
  @cover  = @album.cover_link
  @artist = @album.artist.load
  @tracks = @browse.tracks[0, 20].map(&:load)
  @review = @browse.review
  erb :album
end

get uri_for(:image) do |img|
  image = Hallon::Image.new(img).load
  headers "Content-Type" => "image/#{image.format}"
  image.data
end

get uri_for(:playlist) do |playlist|
  @playlist = Hallon::Playlist.new(playlist).load
  @playlist.update_subscribers
  @owner    = @playlist.owner.load
  @tracks   = @playlist.tracks.to_a
  @echo_nest_ids = @tracks.collect{|x| get_echo_nest_id(x)}
 # @echo_nest_ids = @echo_nest_ids.to_enum
  gon.echo_nest_ids = @echo_nest_ids
  #json_from_echo_nest = get_echo_nest_data_for_tracks(@tracks)
  #@tracks.each do |track|

 #   trk_en_lfm = Track_with_echonest_and_lastfm_data.new(track.to_link.to_uri).load
 #   trk_en_lfm.fetch_properties(json_from_echo_nest)
 # end
  @tracks.each(&:load)
  erb :playlist
end
