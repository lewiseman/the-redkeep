import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app/background/backup_dispatcher.dart';
import 'app/redkeep_app.dart';

void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // Background backups need the entry point registered in every process.
  unawaited(initializeBackgroundBackups().catchError((Object _) {}));
  runApp(const ProviderScope(child: RedkeepApp()));
}
