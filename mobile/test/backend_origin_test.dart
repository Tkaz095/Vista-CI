import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vista_mobile/core/backend_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('New installation uses the Firebase Hosting backend', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await BackendClient.origin(), 'https://vista-ci.web.app');
  });

  test('Old local and Vercel URLs migrate once to Firebase', () async {
    for (final old in [
      'http://localhost:5173',
      'http://127.0.0.1:5173/',
      'https://vista-ci.vercel.app',
    ]) {
      SharedPreferences.setMockInitialValues({'vista.backend.origin': old});
      expect(await BackendClient.origin(), 'https://vista-ci.web.app');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'vista.backend.origin',
        ),
        isNull,
      );
    }
  });

  test('An explicitly chosen custom backend is preserved', () async {
    SharedPreferences.setMockInitialValues({
      'vista.backend.origin': 'https://custom.example.com',
    });
    expect(await BackendClient.origin(), 'https://custom.example.com');
  });

  test('A local development URL can still be chosen after migration', () async {
    SharedPreferences.setMockInitialValues({});
    await BackendClient.origin();
    await BackendClient.saveOrigin('http://localhost:5173');
    expect(await BackendClient.origin(), 'http://localhost:5173');
  });
}
