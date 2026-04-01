import 'package:flutter/cupertino.dart';

Future<T?> pushRootCupertinoPage<T>(
  BuildContext context,
  Widget page,
) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    CupertinoPageRoute(builder: (_) => page),
  );
}
