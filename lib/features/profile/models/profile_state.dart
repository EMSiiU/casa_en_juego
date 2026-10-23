import '../../auth/models/app_user.dart';

class ProfileState {
  const ProfileState({
    required this.user,
    this.isSaving = false,
    this.errorMessage,
  });
  final AppUser user;
  final bool isSaving;
  final String? errorMessage;
}
