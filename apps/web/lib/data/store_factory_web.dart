import 'package:sembast_web/sembast_web.dart';

Future<Database> openStore() =>
    databaseFactoryWeb.openDatabase('attendly-web-v1');
