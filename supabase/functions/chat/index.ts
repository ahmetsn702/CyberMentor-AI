// CyberMentor AI — chat Edge Function
//
// Proxies Gemini chat requests so GEMINI_API_KEY never reaches the client.
// Verifies the caller's Supabase JWT, enforces a per-user rate limit
// (10 requests per rolling 60s), then forwards the conversation history to
// Gemini 2.5 Flash with the appropriate category-specific system prompt and
// returns the reply.
//
// Required Edge Function secret:  GEMINI_API_KEY
// Required public table:          public.rate_limits  (see supabase/schema.sql)
//
// Deploy:
//   supabase functions deploy chat
//   supabase secrets set GEMINI_API_KEY=<key>

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const MODEL = "gemini-2.5-flash";
const GEMINI_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

const RATE_LIMIT_PER_MINUTE = 10;
const RATE_WINDOW_MS = 60_000;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, content-type, apikey, x-client-info",
};

const BASE_PROMPT = `Sen CyberMentor AI'sın, uzman bir siber güvenlik mentoru ve CTF asistanısın.
Görevin öğrencileri Sokratik yöntemle yönlendirmek: cevabı doğrudan vermek yerine,
öğrencinin çözümü kendisinin keşfetmesini sağlayacak düşündürücü sorular sor.

Yanıtlarını kısa, ilgi çekici ve eğitici tut. Öğrenci takıldığında problemi
küçük adımlara böl ve yönlendirici sorular sor. Her zaman cesaretlendirici
ve destekleyici ol. Markdown formatı kullan (kod blokları, kalın, italik).`;

const CATEGORY_PROMPTS: Record<string, string> = {
  "SQL Injection": `${BASE_PROMPT}

Sen SQL Injection konusunda uzmanlaşmış bir mentorsun. Odak alanların:
- SQL sorgu yapısı ve veritabanı mantığı
- UNION-based, blind, error-based ve time-based injection teknikleri
- Parameterized queries ve prepared statements ile savunma
- WAF bypass yöntemleri ve filtre atlatma
- sqlmap gibi araçların kullanımı
- Gerçek dünya senaryoları ve CTF challenge çözümleri

Öğrenci bir SQL injection sorusu sorduğunda, önce sorgunun yapısını anlamasını sağla,
sonra injection noktasını bulmaya yönlendir. Doğrudan payload verme, adım adım düşündür.`,
  "Network Security": `${BASE_PROMPT}

Sen Network Security konusunda uzmanlaşmış bir mentorsun. Odak alanların:
- TCP/IP protokol yığını ve OSI katmanları
- Firewall kuralları, ACL yapılandırması ve ağ segmentasyonu
- Nmap ile port scanning ve servis keşfi
- Wireshark ile paket analizi ve trafik inceleme
- ARP spoofing, MITM saldırıları ve ağ sniffing
- VPN, IDS/IPS sistemleri ve ağ güvenliği mimarisi

Öğrenci bir ağ güvenliği sorusu sorduğunda, önce ilgili protokolü anlamasını sağla,
sonra saldırı vektörünü keşfetmeye yönlendir. Paket yapısından başla, katman katman ilerle.`,
  "Linux": `${BASE_PROMPT}

Sen Linux konusunda uzmanlaşmış bir mentorsun. Odak alanların:
- Bash komut satırı ve shell scripting
- Dosya sistemi, izinler (chmod, chown) ve SUID/SGID bitleri
- Süreç yönetimi, servisler ve cron jobs
- Privilege escalation teknikleri (SUID exploit, kernel exploit, sudo misconfig)
- Log analizi ve sistem izleme
- Linux hardening ve güvenlik yapılandırması

Öğrenci bir Linux sorusu sorduğunda, önce temel komutu anlamasını sağla,
sonra güvenlik implikasyonlarını keşfetmeye yönlendir. Man sayfalarını okumayı teşvik et.`,
  "Cryptography": `${BASE_PROMPT}

Sen Cryptography konusunda uzmanlaşmış bir mentorsun. Odak alanların:
- Simetrik şifreleme (AES, DES) ve asimetrik şifreleme (RSA, ECC)
- Hash fonksiyonları (SHA, MD5) ve bütünlük kontrolü
- PKI altyapısı, dijital sertifikalar ve SSL/TLS
- Encoding vs encryption vs hashing ayrımı
- Kriptanaliz teknikleri ve bilinen saldırılar
- CTF'lerde karşılaşılan kripto challenge türleri

Öğrenci bir kriptografi sorusu sorduğunda, önce algoritmanın matematiğini anlamasını sağla,
sonra zayıf noktaları keşfetmeye yönlendir. Basit örneklerle başla, karmaşığa doğru ilerle.`,
};

function getSystemPrompt(category: string): string {
  return CATEGORY_PROMPTS[category] ?? BASE_PROMPT;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

interface IncomingMessage {
  role?: string;
  content?: string;
}

Deno.serve(async (req: Request) => {
  // CORS preflight — browsers send this before the actual POST.
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // 1. Required env
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey || !geminiKey) {
    return jsonResponse({ error: "Server misconfigured" }, 500);
  }

  // 2. Auth — verify the caller's Supabase JWT.
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing Authorization header" }, 401);
  }
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "Invalid token" }, 401);
  }
  const userId = userData.user.id;

  // 3. Rate limit — rolling 60s window, RATE_LIMIT_PER_MINUTE max requests.
  // Service-role client bypasses RLS so we can read/write public.rate_limits.
  const adminClient = createClient(supabaseUrl, serviceKey);
  const windowStartISO =
    new Date(Date.now() - RATE_WINDOW_MS).toISOString();

  // Trim old rows for this user first — keeps the table bounded per user.
  await adminClient
    .from("rate_limits")
    .delete()
    .eq("user_id", userId)
    .lt("request_at", windowStartISO);

  const { count } = await adminClient
    .from("rate_limits")
    .select("user_id", { count: "exact", head: true })
    .eq("user_id", userId);

  if ((count ?? 0) >= RATE_LIMIT_PER_MINUTE) {
    return jsonResponse(
      { error: "Çok fazla istek. Lütfen bir dakika sonra tekrar dene." },
      429,
    );
  }

  // Record this request before the (slow) Gemini call so concurrent requests
  // in the same window count immediately and can't all slip through.
  await adminClient.from("rate_limits").insert({ user_id: userId });

  // 4. Body
  let history: IncomingMessage[];
  let category: string;
  try {
    const body = await req.json();
    if (!Array.isArray(body?.history) || typeof body?.category !== "string") {
      return jsonResponse(
        { error: "Invalid request body — expected { history: [], category: '' }" },
        400,
      );
    }
    history = body.history;
    category = body.category;
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  // 5. Forward to Gemini
  const contents = history.map((msg) => ({
    role: msg.role === "assistant" ? "model" : "user",
    parts: [{ text: msg.content ?? "" }],
  }));

  let geminiRes: Response;
  try {
    geminiRes = await fetch(`${GEMINI_URL}?key=${geminiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        system_instruction: {
          parts: [{ text: getSystemPrompt(category) }],
        },
        contents,
        generationConfig: { maxOutputTokens: 1024 },
      }),
    });
  } catch (e) {
    return jsonResponse(
      { error: `Gemini'ye ulaşılamadı: ${(e as Error).message}` },
      502,
    );
  }

  if (!geminiRes.ok) {
    const errBody = await geminiRes.text();
    return jsonResponse(
      { error: `Gemini hatası: ${errBody.slice(0, 300)}` },
      502,
    );
  }

  const data = await geminiRes.json();
  const reply = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof reply !== "string") {
    return jsonResponse({ error: "Gemini'den geçerli cevap alınamadı." }, 502);
  }

  return jsonResponse({ reply });
});
