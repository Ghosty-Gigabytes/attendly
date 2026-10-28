import 'package:sembast/sembast.dart';
import 'store_factory.dart'
    if (dart.library.js_interop) 'store_factory_web.dart';

class LocalStore {
  final Database database;
  final records = StoreRef<String, dynamic>.main();
  LocalStore(this.database);
  static Future<LocalStore> open() async => LocalStore(await openStore());
  Future<dynamic> read(String key) => records.record(key).get(database);
  Future<void> write(String key, dynamic value) async {
    await records.record(key).put(database, value);
  }

  Future<String?> preference(String key) async =>
      (await read('pref:$key')) as String?;
  Future<void> setPreference(String key, String value) =>
      write('pref:$key', value);
  Future<void> clear() async {
    await records.delete(database);
  }
}
