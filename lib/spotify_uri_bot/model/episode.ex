defmodule SpotifyUriBot.Model.Episode do
  defstruct [:name, :publisher, :show, :description, :language, :uri, :preview_url, :href]

  def from_api(%{
        "name" => name,
        "show" => %{"name" => show, "publisher" => publisher},
        "description" => description,
        "language" => language,
        "uri" => uri,
        "audio_preview_url" => preview_url,
        "external_urls" => %{"spotify" => href}
      }) do
    episode = %__MODULE__{
      name: name,
      publisher: publisher,
      show: show,
      description: description,
      language: language,
      uri: uri,
      preview_url: preview_url,
      href: href
    }

    {:ok, episode}
  end

  def from_api(_), do: :error
end
