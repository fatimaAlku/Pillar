import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/repositories/recommendations_repository.dart';

class RecommendationsRepositoryImpl implements RecommendationsRepository {
  RecommendationsRepositoryImpl(this._functions, this._db);

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;

  @override
  Future<void> generateRecommendations() async {
    await _functions.httpsCallable('generateRecommendations').call();
  }

  @override
  Stream<Recommendation?> watchLatestRecommendation(String uid) {
    return _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.insights)
        .orderBy('generatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final data = snapshot.docs.first.data();
      final weakAreas = (data['weakAreas'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false);
      final strengths = (data['strengths'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false);
      final rawConfidence = data['confidenceByTopic'];
      final confidenceByTopic = rawConfidence is Map
          ? rawConfidence.map<String, double>((key, value) {
              final parsed =
                  value is num ? value.toDouble() : double.tryParse('$value');
              return MapEntry(
                key.toString(),
                (parsed ?? 0.5).clamp(0.0, 1.0).toDouble(),
              );
            })
          : const <String, double>{};
      final rawQuizSampleSize = data['quizSampleSize'];
      return Recommendation(
        recommendationText:
            (data['recommendationText'] as String?)?.trim().isNotEmpty == true
                ? (data['recommendationText'] as String).trim()
                : 'No recommendation text returned.',
        generatedAtIso: (data['generatedAt'] as String?) ?? '',
        weakAreas: weakAreas,
        strengths: strengths,
        confidenceByTopic: confidenceByTopic,
        quizSampleSize:
            rawQuizSampleSize is num ? rawQuizSampleSize.toInt() : 0,
      );
    });
  }
}
