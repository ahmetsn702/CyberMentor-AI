import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a single `ChatService.sendMessage` call.
///
/// Modeled as a sealed class so the UI can pattern-match on each outcome
/// — they need very different handling and shouldn't be funneled through
/// a single "reply or error string" channel (the previous design polluted
/// chat history with error text).
///
/// - [ChatSuccess]      : assistant reply, render as message + persist.
/// - [ChatBusy]         : Edge Function returned 503 + error_code
///                        "AI_BUSY" (Gemini upstream busy). Transient.
///                        Show a retry banner; do NOT add to message
///                        history or persist. Last user message stays
///                        queued so retry resubmits.
/// - [ChatRateLimited]  : Edge Function returned 429 + error_code
///                        "RATE_LIMITED" (per-user 10 req / 60s cap).
///                        Same UI treatment as ChatBusy (retry banner)
///                        but the user-facing copy explains they should
///                        WAIT a bit before retrying.
/// - [ChatError]        : everything else. Show a snackbar with a generic
///                        message; do NOT add to history or persist. Raw
///                        JSON / stack traces never reach the UI.
sealed class ChatResult {
  const ChatResult();
}

class ChatSuccess extends ChatResult {
  final String reply;
  const ChatSuccess(this.reply);
}

class ChatBusy extends ChatResult {
  final String message;
  const ChatBusy(this.message);
}

class ChatRateLimited extends ChatResult {
  final String message;
  const ChatRateLimited(this.message);
}

class ChatError extends ChatResult {
  final String message;
  const ChatError(this.message);
}

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

  /// Edge Function'a istek atar. Asla throw etmez — sonucu [ChatResult]
  /// sealed class'ı içinde döner. UI üç durumu farklı işler (success bubble,
  /// busy banner, error snackbar). Detaylar için [ChatResult].
  ///
  /// `challengeId` opsiyoneldir: bir challenge bağlamında açılan konuşmada
  /// Edge Function bu id'yi DB'den fetch edip solution_context'i sistem
  /// promptuna ekler — böylece mentor o challenge'a özel ipuçlarıyla
  /// yönlendirme yapar. Client solution_context'i hiç görmez.
  static Future<ChatResult> sendMessage(
    List<Map<String, String>> history,
    String category, {
    String? challengeId,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const ChatError('Oturum bulunamadı. Lütfen tekrar giriş yap.');
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
        if (reply is String) return ChatSuccess(reply);
        debugPrint('[ChatService] 200 but no reply field. data=$data');
        return const ChatError('Bir hata oluştu, tekrar dene.');
      }
      debugPrint('[ChatService] non-200 response: status=${response.status} '
          'data=${response.data}');
      return _interpretError(response.data);
    } on FunctionException catch (e) {
      debugPrint('[ChatService] FunctionException: status=${e.status} '
          'details=${e.details} reason=${e.reasonPhrase}');
      return _interpretError(e.details);
    } catch (e) {
      debugPrint('[ChatService] Unexpected error: $e');
      return const ChatError('Bir hata oluştu, tekrar dene.');
    }
  }

  /// Edge Function {error_code, error} formatında zenginleştirilmiş
  /// hatalar dönüyor:
  ///   - AI_BUSY     → [ChatBusy]        (Gemini upstream busy, retry edilebilir)
  ///   - RATE_LIMITED → [ChatRateLimited] (kullanıcı 60s'de 10 isteği aştı)
  ///   - diğer       → [ChatError]       (generic mesaj, ham JSON gizli)
  /// Ham gövde (status, JSON) sadece debugPrint'e gider; kullanıcıya hiç sızmaz.
  static ChatResult _interpretError(dynamic body) {
    if (body is Map) {
      final code = body['error_code'];
      final msg = body['error'];
      final msgStr = msg is String && msg.isNotEmpty ? msg : null;
      if (code == 'AI_BUSY') {
        return ChatBusy(
          msgStr ?? 'AI şu anda yoğun. Birkaç saniye sonra tekrar dener misin?',
        );
      }
      if (code == 'RATE_LIMITED') {
        return ChatRateLimited(
          msgStr ?? 'Çok fazla istek. Lütfen bir dakika bekle.',
        );
      }
    }
    return const ChatError('Bir hata oluştu, tekrar dene.');
  }
}
