class ReviewActionState {
  const ReviewActionState({this.busyId, this.errorMessage});
  final String? busyId;
  final String? errorMessage;
  bool get isBusy => busyId != null;
}
