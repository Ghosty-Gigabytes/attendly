import 'package:sembast/sembast_memory.dart';

Future<Database> openStore() =>
    databaseFactoryMemory.openDatabase('attendly-web-test');
