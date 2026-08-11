import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/photo_service.dart';
import '../data/resume_repository.dart';
import '../models/resume.dart';

/// Overridden in `main()` once the real store is open, so nothing has to
/// handle a "repository not ready yet" state at every call site.
final repositoryProvider = Provider<ResumeRepository>(
  (ref) => throw UnimplementedError('repositoryProvider must be overridden'),
);

final photoServiceProvider = Provider<PhotoService>((ref) => PhotoService());

/// All saved resumes, newest first.
///
/// Seeded with the current contents rather than waiting for the first change
/// event, so the list screen paints real data on its first frame instead of
/// flashing an empty state at someone who has resumes saved.
final resumeListProvider = StreamProvider<List<ResumeDocument>>((ref) async* {
  final repo = ref.watch(repositoryProvider);
  yield await repo.all();
  yield* repo.watch();
});
