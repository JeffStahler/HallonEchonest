# This is an example project…
It uses [Hallon](https://github.com/Burgestrand/Hallon), [libspotify](http://developer.spotify.com/en/libspotify/overview/) (through Hallon)
and [Sinatra](http://www.sinatrarb.com/). What it does is that it logs in to Spotify on startup, and then tells you if it’s logged in or not
on start page.

## How to get it running
You’ll need your Spotify Premium Account credentials and a [Spotify Application Key](https://developer.spotify.com/en/libspotify/application-key/).
Put the application key in `bin/spotify_appkey.key` and your credentials in your environment variables:

    export HALLON_USERNAME='your_username'
    export HALLON_PASSWORD='your_password'

After this, you’ll want to download the dependencies:

- Ruby 1.9.2+
- [Bundler](http://gembundler.com/)

Finally, install all gems required for your platform by using bundler.

    bundle install

Now, you should have all dependencies.

## Running it on Heroku
Create an application on Heroku, push the application to it, add your Spotify credentials:

    heroku config:add HALLON_USERNAME='your_username'
    heroku config:add HALLON_PASSWORD='your_password'

That’s all there should be to it. Now open it with `heroku open`!

## Running it locally

    foreman start

Done. Open it in your browser on `http://localhost:5000`.