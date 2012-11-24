export HALLON_USERNAME='jeffstahler'
export HALLON_PASSWORD='lalala'
export HALLON_APPKEY="$(ruby bin/serialize_appkey.rb spotify_appkey.key)"
foreman start
