import 'package:hive_flutter/hive_flutter.dart';
import '../../features/auth/models/local_user.dart';
import '../../features/user/models/syllabus_model.dart';

class HiveSetup {
  // Define box names as constants so you don't make typos later
  static const String userBoxName = 'userBox';
  static const String settingsBoxName = 'settingsBox'; // For Dark mode, etc.
  static const String syllabusBoxName = 'syllabusBox'; // Syllabus details

  static Future<void> init() async {
    // 1. Initialize Hive for Flutter
    await Hive.initFlutter();

    // 2. Register your custom TypeAdapters
    // Guard against double registration — calling registerAdapter twice
    // throws a HiveError that causes a crash in release mode.
    if (!Hive.isAdapterRegistered(LocalUserAdapter().typeId)) {
      Hive.registerAdapter(LocalUserAdapter());
    }
    if (!Hive.isAdapterRegistered(SyllabusModelAdapter().typeId)) {
      Hive.registerAdapter(SyllabusModelAdapter());
    }

    // 3. Open the essential boxes we need immediately on startup.
    // Notice we DO NOT open the massive question banks here to keep startup time ultra-fast!
    // The SimulatorService will open those lazily when the user actually starts an exam.
    await Hive.openBox<LocalUser>(userBoxName);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox<SyllabusModel>(syllabusBoxName);
  }
}