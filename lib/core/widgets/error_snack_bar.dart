import 'package:flutter/material.dart';

import '../errors.dart';

void showErrorSnackBar(
  BuildContext context,
  Object error, {
  SnackBarBehavior? behavior,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(AppException.from(error).message),
        behavior: behavior,
      ),
    );
}
