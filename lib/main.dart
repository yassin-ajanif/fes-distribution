import 'package:flutter/material.dart';

import 'db/app_database.dart';
import 'ui/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();

  runApp(FesDistributionApp(database: database));
}
