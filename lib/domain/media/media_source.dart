// lib/domain/media/media_source.dart

/// A single search result from one [MediaSource] -- one candidate anime
/// series/subject that may or may not be the one the caller is looking
/// for. [MediaSource.search] returns these; the caller (see
/// `lib/domain/media/title_matcher.dart`) picks the best match by
/// [title], then passes it to [MediaSource.listEpisodes].
abstract class MediaCandidate {
  /// Which [MediaSource.id] this candidate came from.
  String get sourceId;

  /// Display title, in whatever language/form the source itself uses.
  /// Used for title-matching (see `title_matcher.dart`) -- deliberately
  /// not required to be normalized/translated by the source itself.
  String get title;
}

/// A single playable episode belonging to one [MediaCandidate].
/// [MediaSource.listEpisodes] returns these; the caller passes one to
/// [MediaSource.resolvePlayback] to get an actual playback URL.
abstract class MediaEpisode {
  /// Which [MediaSource.id] this episode came from.
  String get sourceId;

  /// Display title, e.g. an episode number/name.
  String get title;
}

/// A resolved, playable video source for one [MediaEpisode].
abstract class MediaPlaybackSource {
  const MediaPlaybackSource();

  /// Direct video URL (mp4/m3u8/etc).
  String get url;

  /// HTTP headers that must be sent when actually requesting [url] (e.g.
  /// via media_kit's `Media(url, httpHeaders: ...)`). Empty when the
  /// source's CDN needs none.
  Map<String, String> get headers;

  /// Returns the URL that should actually be handed to the player. HTTP
  /// sources return [url] unchanged (the default implementation below). BT
  /// sources override this to download the `.torrent`, hand it to the
  /// torrent engine, and return the resulting local stream URL.
  Future<String> prepare() async => url;

  /// Called when playback of this source ends or a fallback switches away
  /// from it, to release any resources (e.g. a downloading torrent). HTTP
  /// sources need no cleanup, hence the no-op default.
  Future<void> dispose() async {}
}

/// A single video-playback data source (e.g. anime1.me, 稀饭动漫). Each
/// concrete source implements this with its own [MediaCandidate]/
/// [MediaEpisode]/[MediaPlaybackSource] subtypes and internally downcasts
/// the abstract parameters it receives back to its own concrete types --
/// see `lib/domain/media/media_registry.dart`'s adapter classes.
abstract class MediaSource {
  /// Stable identifier, e.g. `'anime1'`/`'xifan'`. Used to route a
  /// [MediaEpisode] back to the [MediaSource] that produced it (see
  /// `EpisodePlayController`) and as the merged-episode-list source badge
  /// (see `SubjectDetailScreen`).
  String get id;

  /// Human-readable name shown in the UI, e.g. `'anime1.me'`/`'稀饭动漫'`.
  String get displayName;

  /// Searches this source for [title], returning every plausible
  /// candidate (not just the best match -- matching is the caller's job,
  /// see `title_matcher.dart`). May throw on network/parse failure; the
  /// caller decides how to handle that (see `SubjectEpisodesController`).
  Future<List<MediaCandidate>> search(String title);

  /// Lists every episode under [candidate] (which must have come from
  /// this same source's [search]).
  Future<List<MediaEpisode>> listEpisodes(MediaCandidate candidate);

  /// Resolves every available playback candidate ("line"/"mirror") for
  /// [episode], in order. Index 0 is the default/primary line; the rest
  /// are ordered fallback candidates a player should try in sequence if
  /// an earlier one fails to play. The returned list is never empty --
  /// implementations throw instead if no candidate could be resolved.
  Future<List<MediaPlaybackSource>> resolvePlayback(MediaEpisode episode);
}
