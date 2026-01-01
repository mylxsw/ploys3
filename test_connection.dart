import 'dart:io';
import 'package:http/http.dart' as http;

/// Simple test to verify network connectivity
void main() async {
  print('Testing network connectivity...');

  // Test 1: Basic internet connectivity
  try {
    final response = await http.get(Uri.parse('https://www.google.com'));
    print('✓ Internet connectivity test passed (Status: ${response.statusCode})');
  } catch (e) {
    print('✗ Internet connectivity test failed: $e');
  }

  // Test 2: R2 endpoint connectivity
  try {
    final r2Response = await http.get(Uri.parse('https://68c0004f9dca0dcfc5edde365a57015d.r2.cloudflarestorage.com'));
    print('✓ R2 endpoint test passed (Status: ${r2Response.statusCode})');
  } catch (e) {
    print('✗ R2 endpoint test failed: $e');
  }

  print('\nPlatform: ${Platform.operatingSystem}');
  print('Process ID: ${pid}');
}