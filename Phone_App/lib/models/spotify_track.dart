class SpotifyTrack {
  final String title;
  final String artist;
  final String album;
  final String? albumArtUrl;
  final int progressMs;
  final int durationMs;
  final bool isPlaying;

  const SpotifyTrack({
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtUrl,
    required this.progressMs,
    required this.durationMs,
    required this.isPlaying,
  });

  double get progressFraction =>
      durationMs > 0 ? (progressMs / durationMs).clamp(0.0, 1.0) : 0.0;

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    return SpotifyTrack(
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      albumArtUrl: json['albumArtUrl'] as String?,
      progressMs: json['progressMs'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 1,
      isPlaying: json['isPlaying'] as bool? ?? false,
    );
  }
}
