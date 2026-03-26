# 🛡️ CyberMentor AI

Siber güvenlik öğrencileri için AI destekli mentor ve CTF asistanı. Sokratik yöntemle çalışarak öğrencilerin cevabı kendilerinin keşfetmesini sağlar; doğrudan çözüm vermek yerine düşündürücü sorularla yönlendirir.

[![GitHub](https://img.shields.io/badge/GitHub-ahmetsn702-181717?style=flat&logo=github)](https://github.com/ahmetsn702)

---

## ✨ Özellikler

- **Sokratik AI Mentor** — Cevabı direkt vermez, sorularla adım adım çözüme yönlendirir
- **Kategori Bazlı Eğitim** — SQL Injection, Network Security, Linux, Cryptography
- **Kategoriye Özel Prompt'lar** — Her alan için uzmanlaşmış sistem talimatları
- **Markdown Destekli Chat** — Kod blokları, kalın/italik, listeler düzgün render edilir
- **Supabase Auth** — Email/şifre ile kayıt ve giriş
- **Profil Yönetimi** — Kullanıcı bilgileri, şifre sıfırlama, hesap yönetimi
- **Çoklu Platform** — Web + Android desteği
- **Dark Tema** — Material Design 3, deep purple renk şeması

---

## 🛠️ Teknoloji Stack

| Teknoloji | Kullanım Amacı |
|-----------|---------------|
| **Flutter** | Cross-platform UI framework |
| **Supabase Auth** | Kullanıcı kimlik doğrulama |
| **Supabase PostgreSQL** | Veritabanı (ileriki haftalarda aktif) |
| **Gemini 2.5 Flash** | AI mentor motoru |
| **flutter_markdown** | Markdown rendering |

---

## 📁 Proje Yapısı

```
lib/
├── main.dart                  # Uygulama giriş noktası, Supabase init
├── auth/
│   └── auth_gate.dart         # Auth durumuna göre yönlendirme
├── pages/
│   ├── login_page.dart        # Giriş ekranı
│   ├── register_page.dart     # Kayıt ekranı
│   ├── home_page.dart         # Kategori seçim ekranı
│   ├── chat_page.dart         # AI sohbet arayüzü (Markdown destekli)
│   └── profile_page.dart      # Profil ve hesap yönetimi
└── services/
    └── gemini_service.dart    # Gemini 2.5 Flash API entegrasyonu
```

---

## 🚀 Kurulum

**1. Projeyi klonla**
```bash
git clone https://github.com/ahmetsn702/CyberMentor-AI.git
cd CyberMentor-AI/cyber_mentor_ai
```

**2. `.env` dosyasını oluştur**
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
GEMINI_API_KEY=your_gemini_api_key
```

**3. Bağımlılıkları yükle**
```bash
flutter pub get
```

**4. Uygulamayı çalıştır**
```bash
flutter run -d chrome    # Web
flutter run -d android   # Android
```

---

## 📅 10 Haftalık Geliştirme Planı

| Hafta | Konu | Durum |
|-------|------|-------|
| 1 | Flutter proje kurulumu, Supabase Auth, Login/Register ekranları | ✅ |
| 2 | Chat ekranı UI, LLM API entegrasyonu, kategori sistemi | ✅ |
| 3 | Profil sayfası, AppBar navigasyonu, hesap yönetimi | ✅ |
| 4 | Kategori bazlı Socratic prompt'lar, Markdown rendering | ✅ |
| 5 | Konuşma geçmişi kaydedilecek, önceki sohbetlere erişim sağlanacak | ⬜ |
| 6 | Supabase Realtime, web ve mobil eş zamanlı çalışacak | ⬜ |
| 7 | Android'de test edilecek, hatalar giderilecek | ⬜ |
| 8 | Hesap ayarları tamamlanacak, profil ekranı geliştirilecek | ⬜ |
| 9 | Arayüz iyileştirilecek, performans testi yapılacak | ⬜ |
| 10 | Demo hazırlanacak, sunum tamamlanacak | ⬜ |

---

## 🌿 Branch Yapısı

| Branch | Açıklama |
|--------|----------|
| `main` | En güncel ve kararlı sürüm |
| `hafta-1` | Flutter kurulum, Supabase Auth |
| `hafta-2` | Chat UI, Gemini API entegrasyonu |
| `hafta-3` | Profil sayfası |
| `hafta-4` | Kategori bazlı prompt'lar, Markdown |

---

## 👨‍💻 Geliştirici

**Ahmed Hüsrev Sayın**
Yazılım Mühendisliği — Fırat Üniversitesi

[![GitHub](https://img.shields.io/badge/GitHub-ahmetsn702-181717?style=for-the-badge&logo=github)](https://github.com/ahmetsn702)

---

## 📄 Lisans

Bu proje **Fırat Üniversitesi Yazılım Mühendisliği** bölümü, **Web Programlama** dersi kapsamında geliştirilmektedir.
