import 'app_failure.dart';

String appErrorMessage(Object error) {
  if (error is AppFailure) {
    return error.message;
  }

  return 'An unexpected error occurred. Please try again.';
}
