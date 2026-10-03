import 'package:flutter/material.dart';

/// Opens [builder] as a regular page (back gesture/button to close) instead of
/// a modal sheet or dialog: nothing in the app is drawn over another screen.
Future<void> pushDetailPage(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: title != null ? Text(title) : null),
        body: SafeArea(top: false, child: builder(ctx)),
      ),
    ),
  );
}
