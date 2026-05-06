import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

void main() async {
  final url = Uri.parse(Platform.environment['NEXT_PUBLIC_SUPABASE_URL']! + '/rest/v1/');
  final key = Platform.environment['NEXT_PUBLIC_SUPABASE_ANON_KEY']!;
  final response = await http.get(url, headers: {'apikey': key, 'Accept': 'application/openapi+json'});
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final definitions = data['definitions'] as Map<String, dynamic>;
    for (var table in definitions.keys) {
      if (table.toLowerCase().contains('miss')) {
        print(table);
      }
    }
  } else {
    print('Failed: ${response.statusCode}');
  }
}
