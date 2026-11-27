import 'package:permission_handler/permission_handler.dart';

/// Demande l'accès au réseau local (Android 17 et après) ; sur les versions plus anciennes la
/// permission n'existe pas et la demande est accordée d'office.
Future<bool> requestLocalNetworkAccess() async {
  try {
    final vStatus = await Permission.accessLocalNetwork.request();

    return vStatus != PermissionStatus.permanentlyDenied && vStatus != PermissionStatus.denied;
  } on Object {
    return true;
  }
}
