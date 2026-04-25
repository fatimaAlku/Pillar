import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/entities/auth_user.dart';
import '../../features/profile/data/repositories/user_profile_repository_impl.dart';
import '../../features/profile/data/local/local_profile_photo_store.dart';
import '../../features/profile/data/local/local_profile_avatar_store.dart';
import '../../features/profile/domain/entities/user_profile_data.dart';
import '../../features/profile/domain/repositories/user_profile_repository.dart';
import '../../features/progress/data/repositories/progress_repository_impl.dart';
import '../../features/progress/domain/repositories/progress_repository.dart';
import '../../features/quizzes/data/repositories/quiz_history_repository_impl.dart';
import '../../features/quizzes/domain/entities/quiz_history_entry.dart';
import '../../features/quizzes/domain/repositories/quiz_history_repository.dart';
import '../../features/subjects/data/repositories/subjects_repository_impl.dart';
import '../../features/subjects/domain/entities/subject.dart';
import '../../features/subjects/domain/repositories/subjects_repository.dart';
import '../ai/ai_service.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore_service.dart';
import '../firebase/storage_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final storageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final functionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(firestoreProvider));
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(storageProvider));
});

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(ref.watch(functionsProvider));
});

final authRepositoryProvider = Provider<AuthRepositoryImpl>((ref) {
  return AuthRepositoryImpl(
    ref.watch(firebaseAuthProvider),
    ref.watch(storageProvider),
  );
});

final currentAuthUserProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchAuthUser();
});

final subjectsRepositoryProvider = Provider<SubjectsRepository>((ref) {
  return SubjectsRepositoryImpl(ref.watch(firestoreProvider));
});

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepositoryImpl(ref.watch(firestoreProvider));
});

final userProfileStreamProvider =
    StreamProvider.family<UserProfileData?, String>((ref, uid) {
  return ref.watch(userProfileRepositoryProvider).watchProfile(uid);
});

final localProfilePhotoStoreProvider = Provider<LocalProfilePhotoStore>((ref) {
  return LocalProfilePhotoStore();
});

final localProfilePhotoPathProvider =
    FutureProvider.family<String?, String>((ref, uid) {
  return ref.watch(localProfilePhotoStoreProvider).getPhotoPath(uid);
});

final localProfileAvatarStoreProvider =
    Provider<LocalProfileAvatarStore>((ref) {
  return LocalProfileAvatarStore();
});

final localProfileAvatarIdProvider =
    FutureProvider.family<String?, String>((ref, uid) {
  return ref.watch(localProfileAvatarStoreProvider).getSelectedAvatarId(uid);
});

final progressRepositoryImplProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepositoryImpl(ref.watch(firestoreProvider));
});

final quizHistoryRepositoryProvider = Provider<QuizHistoryRepository>((ref) {
  return QuizHistoryRepositoryImpl(ref.watch(firestoreProvider));
});

final subjectsStreamProvider =
    StreamProvider.family<List<Subject>, String>((ref, uid) {
  return ref.watch(subjectsRepositoryProvider).watchSubjects(uid);
});

final quizHistoryStreamProvider =
    StreamProvider.family<List<QuizHistoryEntry>, String>((ref, uid) {
  return ref.watch(quizHistoryRepositoryProvider).watchHistory(uid);
});
