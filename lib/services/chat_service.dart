import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Client wrapper around the `chat` Supabase Edge Function.
///
/// The Gemini API key now lives as an Edge Function secret on the server, so
/// this class only ships the user's history + category to our function and
/// returns the reply string. Auth is handled automatically by the supabase
/// SDK (it attaches the current session's JWT to the invoke call).
class ChatService {
  static const Map<String, String> _welcomeMessages = {
    'SQL Injection':
        'SQL Injection dünyasına hoş geldin! Veritabanlarının nasıl sorgulandığını ve bu sorguların nasıl manipüle edilebileceğini birlikte keşfedeceğiz. Hangi konuda çalışıyorsun? Bir CTF challenge mı çözüyorsun, yoksa temelden mi başlamak istiyorsun?',
    'Network Security':
        'Network Security dünyasına hoş geldin! Ağ protokollerinden paket analizine, firewall\'lardan sızma testlerine kadar her konuda sana rehberlik edeceğim. Hangi konuda çalışıyorsun? Bir pcap dosyası mı inceliyorsun, yoksa ağ tarama mı öğrenmek istiyorsun?',
    'Linux':
        'Linux dünyasına hoş geldin! Komut satırından privilege escalation\'a kadar her konuda birlikte çalışacağız. Hangi konuda çalışıyorsun? Bir CTF makinesinde mi takıldın, yoksa temel komutlardan mı başlamak istiyorsun?',
    'Cryptography':
        'Cryptography dünyasına hoş geldin! Şifreleme algoritmalarından hash fonksiyonlarına, dijital sertifikalardan kriptanalize kadar her konuda sana rehberlik edeceğim. Hangi konuda çalışıyorsun? Bir şifreli mesajı mı çözmeye çalışıyorsun, yoksa temel kavramlardan mı başlamak istiyorsun?',
  };

  static String getWelcomeMessage(String category) {
    return _welcomeMessages[category] ??
        'Merhaba! Ben CyberMentor AI. **$category** konusunda öğrenmeye hazır mısın? Sorunla başla, seni adım adım çözüme götüreceğim.';
  }

  /// Returns the assistant reply, or a Turkish error message string. Errors
  /// are returned (not thrown) so the chat UI can render them inline as an
  /// assistant bubble — this preserves the contract the previous Gemini
  /// client used.
  ///
  /// `challengeId` opsiyoneldir: bir challenge bağlamında açılan konuşmada
  /// Edge Function bu id'yi DB'den fetch edip solution_context'i sistem
  /// promptuna ekler — böylece mentor o challenge'a özel ipuçlarıyla
  /// yönlendirme yapar. Client solution_context'i hiç görmez.
  static Future<String> sendMessage(
    List<Map<String, String>> history,
    String category, {
    String? challengeId,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return 'Hata: Oturum bulunamadı. Lütfen tekrar giriş yap.';
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'chat',
        body: {
          'history': history,
          'category': category,
          'challenge_id': ?challengeId,
        },
      );

      // Some supabase_flutter versions return non-2xx responses without
      // throwing; handle both that path and the FunctionException path.
      if (response.status == 200) {
        final data = response.data;
        final reply = (data is Map) ? data['reply'] : null;
        if (reply is String) return reply;
        debugPrint('[ChatService] 200 but no reply field. data=$data');
        return 'Hata: Sunucudan geçersiz cevap alındı.';
      }
      debugPrint('[ChatService] non-200 response: status=${response.status} '
          'data=${response.data}');
      return _formatError(response.status, response.data);
    } on FunctionException catch (e) {
      debugPrint('[ChatService] FunctionException: status=${e.status} '
          'details=${e.details} reason=${e.reasonPhrase}');
      return _formatError(e.status, e.details);
    } catch (e) {
      debugPrint('[ChatService] Unexpected error: $e');
      return 'Bağlantı hatası: $e';
    }
  }

  static String _formatError(int status, dynamic body) {
    final extracted = _extractError(body);
    if (extracted != null) return 'Hata: $extracted';
    if (status == 401) {
      // Gateway rejection (function never ran) vs. our own 401 both surface
      // here; the diagnostic guidance is the same either way.
      return 'Hata: HTTP 401 — Edge Function deploy edilmemiş olabilir veya '
          'oturum geçersiz. Konsol log\'larına ve DevTools Network sekmesine bak.';
    }
    return 'Hata: HTTP $status';
  }

  static String? _extractError(dynamic body) {
    if (body is Map) {
      // Our function returns {error}; gateway sometimes returns {message} or
      // {msg}; cover the common shapes.
      for (final key in const ['error', 'message', 'msg']) {
        final v = body[key];
        if (v is String && v.isNotEmpty) return v;
      }
    }
    if (body is String && body.isNotEmpty) return body;
    return null;
  }
}
