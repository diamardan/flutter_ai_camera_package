import 'package:flutter_riverpod/flutter_riverpod.dart';

class CaptureState {
  final bool validating;
  final String message;

  CaptureState({this.validating = false, this.message = ''});

  CaptureState copyWith({bool? validating, String? message}) {
    return CaptureState(
      validating: validating ?? this.validating,
      message: message ?? this.message,
    );
  }
}

class CaptureStateNotifier extends StateNotifier<CaptureState> {
  CaptureStateNotifier(): super(CaptureState());

  void setValidating(bool v) => state = state.copyWith(validating: v);
  void setMessage(String m) => state = state.copyWith(message: m);
}

final captureStateProvider = StateNotifierProvider<CaptureStateNotifier, CaptureState>((ref) {
  return CaptureStateNotifier();
});
