# 🛡️ CyberMentor AI

Siber güvenlik öğrencileri için AI destekli mentor ve CTF asistanı. Sokratik yöntemle çalışarak öğrencilerin cevabı kendilerinin keşfetmesini sağlar; doğrudan çözüm vermek yerine düşündürücü sorularla yönlendirir.

[![GitHub](https://img.shields.io/badge/GitHub-ahmetsn702-181717?style=flat&logo=github)](https://github.com/ahmetsn702)

---

## ✨ Özellikler

- **Sokratik AI Mentor** — Cevabı direkt vermez, sorularla adım adım çözüme yönlendirir
- **Kategori Bazlı Eğitim** — SQL Injection, Network Security, Linux, Cryptography
- **Kategoriye Özel Prompt'lar** — Her alan için uzmanlaşmış sistem talimatları
- **Markdown Destekli Chat** — Kod blokları, kalın/italik, listeler, başlıklar düzgün render edilir
- **Konuşma Geçmişi** — Tüm sohbetler Supabase Postgres'te saklanır, geçmiş ekranından açılıp devam ettirilebilir
- **Realtime Senkronizasyon** — Web ve mobilde aynı kullanıcının açık sohbetleri Supabase Realtime üzerinden anlık eşitlenir
- **Sohbet Silme** — Geçmişten istediğin sohbeti onaylı dialog ile silebilirsin (cascade ile mesajlar da gider)
- **Supabase Auth** — Email/şifre ile kayıt ve giriş; oturum durumu `AuthGate` üzerinden yönetilir
- **Kullanıcı Yönetimi** — Display name düzenleme, eski şifre doğrulamalı şifre değiştirme, iki aşamalı onaylı hesap silme
- **Çoklu Platform** — Web (birincil) + Android desteği
- **Dark Tema** — Material Design 3, deep purple renk şeması

---

## 🛠️ Teknoloji Stack

| Teknoloji | Kullanım Amacı |
|-----------|---------------|
| **Flutter** | Cross-platform UI framework (Dart SDK ^3.10.4) |
| **Supabase Auth** | Kullanıcı kimlik doğrulama |
| **Supabase Postgres** | Konuşma ve mesajların kalıcı depolanması, RLS ile veri izolasyonu |
| **Supabase Realtime** | `messages` tablosundaki insert event'lerini cihazlar arası taşıma |
| **Google Gemini 2.5 Flash** | AI mentor motoru (REST API ile doğrudan client'tan çağrılır) |
| **flutter_markdown** | Asistan mesajlarının Markdown render'ı |
| **flutter_dotenv** | Asset olarak paketlenen `.env` dosyasının okunması |

---

## 📁 Proje Yapısı

```
cyber_mentor_ai/
├── lib/
│   ├── main.dart                  # Uygulama giriş noktası, dotenv & Supabase init
│   ├── auth/
│   │   └── auth_gate.dart         # Auth durumuna göre Login/Home yönlendirme
│   ├── pages/
│   │   ├── login_page.dart        # Giriş ekranı
│   │   ├── register_page.dart     # Kayıt ekranı
│   │   ├── home_page.dart         # Kategori seçim ekranı (4 kart)
│   │   ├── chat_page.dart         # Sohbet UI + Realtime abone + Markdown
│   │   ├── history_page.dart      # Konuşma listesi, silme, devam ettirme
│   │   └── profile_page.dart      # Profil, hesap yönetimi, hesap silme
│   └── services/
│       └── gemini_service.dart    # Gemini 2.5 Flash REST entegrasyonu
├── supabase/
│   └── schema.sql                 # Tablolar, indeksler, RLS politikaları, delete_user RPC
├── .env.example                   # .env şablonu (boş key'lerle)
└── pubspec.yaml
```

---

## 🚀 Kurulum

**1. Projeyi klonla**
```bash
git clone https://github.com/ahmetsn702/CyberMentor-AI.git
cd CyberMentor-AI/cyber_mentor_ai
```

**2. `.env` dosyasını oluştur**

`.env.example`'ı kopyalayıp kendi anahtarlarınla doldur:
```bash
cp .env.example .env
```

```env
SUPABASE_URL=https://<proje-id>.supabase.co
SUPABASE_ANON_KEY=<supabase-anon-key>
GEMINI_API_KEY=<google-ai-studio-key>
```

- Supabase URL ve anon key: Supabase dashboard → **Project Settings → API**
- Gemini API key: [ai.google.dev](https://ai.google.dev) (Google AI Studio)

**3. Supabase şemasını kur**

Supabase dashboard → **SQL Editor** → `supabase/schema.sql` içeriğini yapıştır → **Run**.

Bu betik şunları kurar:
- `conversations` ve `messages` tabloları (cascade delete ile)
- Kullanıcının yalnızca kendi verilerini görmesi/değiştirmesi için RLS politikaları
- Hesap silme için `delete_user()` SECURITY DEFINER RPC fonksiyonu

> **Realtime için ek adım:** Supabase dashboard → **Database → Replication** altında `messages` tablosu için Realtime'ı aktif et, yoksa cihazlar arası senkron çalışmaz.

**4. Bağımlılıkları yükle**
```bash
flutter pub get
```

**5. Uygulamayı çalıştır**
```bash
flutter run -d chrome    # Web (birincil hedef)
flutter run -d android   # Android cihaz/emülatör
```

---

## 📸 Ekran Görüntüleri

> Ekran görüntüleri `docs/screenshots/` altına eklenecek.

| Login | Anasayfa | Sohbet | Geçmiş | Profil |
|-------|----------|--------|--------|--------|
| _eklenecek_ | _eklenecek_ | _eklenecek_ | _eklenecek_ | _eklenecek_ |

---

## 📅 10 Haftalık Geliştirme Planı

| Hafta | Konu | Durum |
|-------|------|-------|
| 1 | Flutter proje kurulumu, Supabase Auth, Login/Register ekranları | ✅ |
| 2 | Chat ekranı UI, LLM API entegrasyonu, kategori sistemi | ✅ |
| 3 | Profil sayfası, AppBar navigasyonu | ✅ |
| 4 | Kategori bazlı Socratic prompt'lar, Markdown rendering | ✅ |
| 5 | Konuşma geçmişi (Supabase Postgres), önceki sohbetlere devam | ✅ |
| 6 | Supabase Realtime, web ve mobil eş zamanlı çalışıyor | ✅ |
| 7 | Android testi tamamlandı, web-mobil realtime sync doğrulandı | ✅ |
| 8 | Kullanıcı yönetimi (display name, şifre değiştirme, hesap silme) | ✅ |
| 9 | UI polish, empty/error state'leri, sohbet silme | ✅ |
| 10 | Dokümantasyon, `.env.example`, son kontroller | ✅ |

---

## 🌿 Branch Yapısı

| Branch | Açıklama |
|--------|----------|
| `main` | En güncel ve kararlı sürüm |
| `hafta-1` | Flutter kurulum, Supabase Auth |
| `hafta-2` | Chat UI, LLM API entegrasyonu |
| `hafta-3` | Profil sayfası |
| `hafta-4` | Kategori bazlı prompt'lar, Markdown |
| `hafta-5` | Konuşma geçmişi, sohbete devam |
| `hafta-6` | Realtime chat senkronizasyonu |
| `hafta-7` | Android testi, dependency güncellemeleri |
| `hafta-8` | Kullanıcı yönetimi (display name, şifre, hesap silme) |
| `hafta-9` | UI polish, empty/error state'leri, sohbet silme |
| `hafta-10` | Dokümantasyon ve son polish |

---

## 🔒 Güvenlik Notu

`GEMINI_API_KEY` bundle'a paketlenen `.env` asset'inden okunur — derlenmiş artifakt'a erişen biri anahtarı çıkarabilir. Ders/demo kapsamında bu kabul edilebilir; üretim için LLM çağrılarının bir Supabase Edge Function üzerinden proxy'lenmesi önerilir.

Hesap silme `public.delete_user()` SECURITY DEFINER fonksiyonu üzerinden çalışır; gövde `auth.uid()` ile sınırlı olduğu için kullanıcı yalnızca kendi hesabını silebilir, başkasını değil.

---

## 👨‍💻 Geliştirici

**Ahmed Hüsrev Sayın**
Yazılım Mühendisliği — Fırat Üniversitesi

[![GitHub](https://img.shields.io/badge/GitHub-ahmetsn702-181717?style=for-the-badge&logo=github)](https://github.com/ahmetsn702)

---

## 📄 Lisans

Bu proje **Fırat Üniversitesi Yazılım Mühendisliği** bölümü, **Web Programlama** dersi kapsamında geliştirilmektedir.
