import 'package:flutter/material.dart';

import 'app/admin_app.dart';
import 'services/supabase_config.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await SyncService.instance.init();
  runApp(const AdminApp());
}