import 'dart:async';
import 'package:flutter/material.dart';

/// Runs a save while a spinner blocks the screen, so the app never looks
/// frozen. Gives up after [timeout]. Returns null when it worked, otherwise
/// the error (a [TimeoutException] when it took too long).
Future<Object?> runWithProgress(
  BuildContext context,
  Future<void> Function() task, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    await task().timeout(timeout);
    return null;
  } catch (e) {
    return e;
  } finally {
    if (nav.canPop()) nav.pop();
  }
}
