import 'package:shared_preferences/shared_preferences.dart';

/// Paused: project membership now lives in Firestore. Kept for old local data;
/// the project feature does not call this service or migrate its saved IDs.
class ProjectPreferencesService {
  Future<Set<int>> readFollowedIds(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList('followed_repos_$uid') ?? [];
    return values.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> saveFollowedIds(String uid, Set<int> ids) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setStringList(
      'followed_repos_$uid',
      ids.map((id) => '$id').toList(),
    );
    if (!saved) throw StateError('Could not save followed repositories');
  }
}
