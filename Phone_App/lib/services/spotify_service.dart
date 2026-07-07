import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/spotify_track.dart';

class SpotifyService {
  AppSettings _settings;
  SpotifyTrack? _currentTrack;
  Timer? _pollTimer;
  void Function()? onTrackChanged;
  String? _lastTitle;

  SpotifyService(this._settings);

  SpotifyTrack? get currentTrack => _currentTrack;

  void start() {
    if (!_settings.spotifyEnabled) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    _poll(); // immediate first poll
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void updateSettings(AppSettings settings) {
    _settings = settings;
    stop();
    if (settings.spotifyEnabled) start();
  }

  void dispose() {
    stop();
    onTrackChanged = null;
  }

  Future<void> _poll() async {
    if (!_settings.spotifyEnabled) return;
    final baseUrl = _settings.fridayBaseUrl.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$baseUrl/api/spotify/now-playing');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 2));
      if (resp.statusCode != 200) return;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final playing = data['playing'] as bool? ?? false;
      if (!playing) {
        if (_currentTrack != null) {
          _currentTrack = null;
          _lastTitle = null;
          onTrackChanged?.call();
        }
        return;
      }
      final track = SpotifyTrack.fromJson(data);
      final titleChanged = track.title != _lastTitle;
      _currentTrack = track;
      if (titleChanged) {
        _lastTitle = track.title;
      }
      onTrackChanged?.call(); // always notify for progress updates
    } on TimeoutException {
      // Friday server unreachable — silent fail
    } catch (_) {
      // Any other error — silent fail
    }
  }
}
