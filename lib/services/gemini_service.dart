import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const String _systemPrompt = '''
You are CyberMentor AI, an expert cybersecurity mentor and CTF assistant.
Your role is to guide learners using the Socratic method: instead of directly
giving answers, ask thoughtful questions that lead the student to discover
the solution themselves.

You specialize in:
- SQL Injection
- Network Security
- Linux command line and privilege escalation
- Cryptography

Keep responses concise, engaging, and educational. When a student is stuck,
break the problem into smaller steps and ask guiding questions.
Always be encouraging and supportive.
''';

  static Future<String> sendMessage(List<Map<String, String>> history) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return 'Error: GEMINI_API_KEY is not set in the .env file.';
    }

    try {
      final contents = history.map((msg) {
        return {
          'role': msg['role'] == 'assistant' ? 'model' : msg['role'],
          'parts': [
            {'text': msg['content'] ?? ''}
          ],
        };
      }).toList();

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [
              {'text': _systemPrompt}
            ],
          },
          'contents': contents,
          'generationConfig': {
            'maxOutputTokens': 1024,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      } else {
        final error = jsonDecode(response.body);
        return 'API Error: ${error['error']['message'] ?? 'Unknown error'}';
      }
    } catch (e) {
      return 'Connection error: $e';
    }
  }
}
