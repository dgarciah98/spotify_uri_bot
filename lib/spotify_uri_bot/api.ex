defmodule SpotifyUriBot.Api do
  use Tesla

  plug(Tesla.Middleware.FormUrlencoded)

  require Logger

  alias SpotifyUriBot.Model.{Track, Artist, Album, Playlist, Show, Episode, Search}

  def client(client_token) do
    middlewares = [
      {Tesla.Middleware.BaseUrl, "https://accounts.spotify.com"},
      {Tesla.Middleware.Headers, [{"Authorization", "Basic #{client_token}"}]}
    ]

    Tesla.client(middlewares)
  end

  def authorized_client(token) do
    middlewares = [
      {Tesla.Middleware.BaseUrl, "https://api.spotify.com/v1"},
      {Tesla.Middleware.Headers, [{"Authorization", "Bearer #{token}"}]},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middlewares)
  end

  def get_token() do
    client_token = ExGram.Config.get(:spotify_uri_bot, :client_token)

    with {:ok, %{body: body}} <-
           client_token |> client() |> post("/api/token", %{grant_type: "client_credentials"}),
         {:ok, %{"access_token" => token}} <- Jason.decode(body) do
      Logger.debug("Spotify token gathered.")
      {:ok, token}
    else
      err ->
        Logger.error("Get token failed with error: #{inspect(err)}")
        Logger.error("Retrying...")
        Process.sleep(500)
        get_token()
    end
  end

  def get_track(track_id, token) do
    with {:ok, %{body: body}} <- token |> authorized_client() |> get("/tracks/#{track_id}"),
         {:ok, track} <- Track.from_api(body),
         {:ok, %{genres: genres}} <- get_artist(track.artist_id, token),
         track = Track.add_genres(track, genres) do
      {:ok, track}
    else
      err ->
        Logger.error("Get track failed with error: #{inspect(err)}")
        Logger.error("Retrying...")
        Process.sleep(500)
        get_track(track_id, token)
    end
  end

  def get_album(album_id, token) do
    with {:ok, %{body: body}} <- token |> authorized_client() |> get("/albums/#{album_id}"),
         {:ok, album} <- Album.from_api(body),
         tracks = Enum.map(album.tracks, &Track.from_album(&1, album)),
         {:ok, %{genres: genres}} <- get_artist(album.artist_id, token),
         tracks = Enum.map(tracks, &Track.add_genres(&1, genres)),
         album = Album.add_tracks(album, tracks) do
      {:ok, album}
    else
      err ->
        Logger.error("Get album failed with error: #{inspect(err)}")
        Logger.error("Retrying...")
        Process.sleep(500)
        get_album(album_id, token)
    end
  end

  def get_artist(artist_id, token) do
    with {:ok, %{body: body}} <- token |> authorized_client() |> get("/artists/#{artist_id}"),
         {:ok, artist} <- Artist.from_api(body) do
      {:ok, artist}
    else
      err ->
        Logger.error("Get artist failed with error: #{inspect(err)}")
        Logger.error("Retrying...")
        Process.sleep(500)
        get_artist(artist_id, token)
    end
  end

  def get_artist_top_tracks(artist_id, token) do
    with {:ok, %{body: body}} <-
           token
           |> authorized_client()
           |> get("/artists/#{artist_id}/top-tracks", query: [country: "ES"]),
         tracks = Track.from_top_tracks(body) do
      {:ok, tracks}
    else
      err ->
        Logger.error("Get artist top tracks failed with error: #{inspect(err)}")
        Logger.error("Retrying...")
        Process.sleep(500)
        get_artist_top_tracks(artist_id, token)
    end
  end

  def get_playlist(playlist_id, token) do
    with {:ok, %{body: body}} <- token |> authorized_client() |> get("/playlists/#{playlist_id}"),
         {:ok, playlist} <- Playlist.from_api(body) do
      {:ok, playlist}
    else
      err ->
        Logger.error("Get playlist failed with error: #{inspect(err)}")
    end
  end

  def get_show(show_id, token) do
    with {:ok, %{body: body}} <- token |> authorized_client() |> get("/shows/#{show_id}"),
         {:ok, show} <- Show.from_api(body) do
      {:ok, show}
    else
      err ->
        Logger.error("Get show failed with error: #{inspect(err)}")
        Logger.error("Retrying...")
        Process.sleep(500)
        get_show(show_id, token)
    end
  end

  def get_episode(episode_id, token) do
    with {:ok, %{body: body}} <- token |> authorized_client() |> get("/episodes/#{episode_id}"),
         {:ok, episode} <- Episode.from_api(body) do
      {:ok, episode}
    else
      err ->
        Logger.error("Get episode failed with error: #{inspect(err)}")
        Logger.error("Retrying...")
        Process.sleep(500)
        get_episode(episode_id, token)
    end
  end

  def search("", _, _), do: :ignore

  def search(query, types, token) do
    Logger.info("Searching '#{inspect(query)}' with types '#{inspect(types)}'")
    formatted_types = Enum.join(types, ",")
    params = [q: URI.encode(query), type: formatted_types, limit: 5]

    with {:ok, %{body: body}} <- token |> authorized_client() |> get("/search", query: params),
         {:ok, search_result} <- Search.from_api(body) do
      {:ok, search_result}
    else
      err ->
        Logger.error("Search failed with error: #{inspect(err)}")
        Logger.error("Retrying...")
        Process.sleep(500)
        search(query, types, token)
    end
  end
end
