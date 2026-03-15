import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ClaudeService {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-3-5-haiku-20241022';
  static const String _apiVersion = '2023-06-01';

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
    final apiKey = dotenv.env['CLAUDE_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return 'Error: CLAUDE_API_KEY is not set in the .env file.';
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': _apiVersion,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 1024,
          'system': _systemPrompt,
          'messages': history,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'] as String;
      } else {
        final error = jsonDecode(response.body);
        return 'API Error: ${error['error']['message'] ?? 'Unknown error'}';
      }
    } catch (e) {
      return 'Connection error: $e';
    }
  }
}
