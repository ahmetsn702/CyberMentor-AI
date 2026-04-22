-- CyberMentor AI — challenge bank seed data
--
-- 16 educational CTF challenges (4 per category) at PicoCTF / TryHackMe
-- introductory level. All content is conceptual — no working exploit
-- payloads, no real credentials, no live target IPs. The goal is to teach
-- the *idea* behind a technique so the AI mentor can guide the student
-- Socratically.
--
-- Idempotent: safe to re-run. `on conflict (slug) do nothing` leaves
-- existing rows untouched, so manual edits via the Supabase dashboard
-- survive a re-seed. To bulk-update a row, delete it first and re-seed.
--
-- Run after schema.sql:
--   supabase db push --include-seed
--   psql "$SUPABASE_DB_URL" -f supabase/seed.sql

insert into public.challenges
  (slug, title, category, difficulty, description, hints, learning_objective, solution_context)
values

-- ─── SQL Injection ───────────────────────────────────────────────────

(
  'sqli-login-bypass',
  'Login Bypass',
  'SQL Injection',
  'Kolay',
  $$Bir login formu kullanıcı adı ve şifre alıyor; bu girdileri hiçbir sanitization yapmadan doğrudan SQL sorgusuna yapıştırıyor:

SELECT * FROM users WHERE username='[input]' AND password='[input]'

Hedefin: 'admin' kullanıcısı olarak şifresini bilmeden giriş yapmak. Kullanıcı adı alanına ne yazarsan, password kontrolünü tamamen atlayabilirsin?$$,
  array[
    $$SQL'de yorum karakterleri (-- ve #) sorgunun geri kalanını yok sayar.$$,
    $$WHERE koşulundaki "AND password=..." kısmını devre dışı bırakırsan, sorgu sadece username kontrolüne dayanır. Bunu nasıl yaparsın?$$,
    $$Username alanına yaz:  admin'--  (sonunda boşluk var). Sorgu nasıl yorumlanır? Kalan AND password kısmı ne olur?$$
  ],
  $$SQL sorgu yapısının kullanıcı girdisiyle nasıl bozulabileceğini anlamak. String concatenation ile parameterized query arasındaki farkı kavramak. Authentication mantığının neden tek başına yetersiz olduğunu fark etmek.$$,
  $$Klasik auth bypass: input "admin'-- " olunca sorgu  WHERE username='admin'-- ' AND password='x'  haline gelir. -- sonrası yorum, AND password çalışmaz. Çözüm: prepared statements (PreparedStatement, $1/?), input doğrulama, parolaları bcrypt/argon2 ile hash'le, ORM kullan.$$
),

(
  'sqli-union-based',
  'UNION-based Veri Çıkarma',
  'SQL Injection',
  'Orta',
  $$Bir ürün listeleme sayfası id parametresi alıyor:  /products?id=5

Arka planda çalışan sorgu:  SELECT name, price FROM products WHERE id=[input]

Hedefin: aynı endpoint üzerinden users tablosundan kullanıcı adlarını ve email'leri çekmek. UNION operatörünü nasıl kullanırsın?$$,
  array[
    $$UNION SELECT iki sorgunun sonucunu birleştirir; ama sütun sayısı ve veri tipleri eşleşmek zorundadır.$$,
    $$Önce orijinal sorgunun kaç sütun döndürdüğünü öğrenmen gerekiyor. ORDER BY 1, ORDER BY 2 ... ile test edebilirsin — hata verdiği sayı sınırı gösterir.$$,
    $$Sütun sayısını bulduktan sonra UNION SELECT NULL,NULL ile match et, sonra NULL'ları users tablosundan gelen sütunlarla değiştir. Tablo isimlerini bilmiyorsan information_schema.tables var.$$
  ],
  $$UNION operatörünün davranışını ve kısıtlarını anlamak. information_schema metadata sayesinde DB yapısının nasıl keşfedildiğini görmek. Neden least-privilege DB user'ı (read-only ama tüm tablolara okuma değil) önemlidir.$$,
  $$Adım: 1) ORDER BY ile sütun sayısı bul. 2) UNION SELECT NULL,NULL,...  ile match et. 3) NULL'ları information_schema.columns'dan çekilen tablo/kolon isimleriyle değiştir. 4) UNION SELECT username,email FROM users ile veriyi al. Önlem: prepared statements + DB user'ı sadece kendi tablosunu görsün.$$
),

(
  'sqli-blind',
  'Blind SQL Injection',
  'SQL Injection',
  'Orta',
  $$Bir arama formu var. Sonuç sadece "Bulundu" veya "Bulunamadı" diyor. Hata mesajı görünmüyor, veri ekrana basılmıyor. Yine de DB içinden veri çıkarman gerekiyor. Bu duruma ne diyoruz ve hangi kanallar üzerinden bilgi sızdırılır?$$,
  array[
    $$Boolean-based blind: AND ile bir koşul ekle. Sayfa "Bulundu" derse koşul doğru, "Bulunamadı" derse yanlış. Bu 1-bit bir kanal.$$,
    $$Veriyi karakter-karakter çıkarmak gerekir. SUBSTRING(...) ile bir karakteri ASCII karşılaştırma yaparsın: > 'm' mi, > 'a' mı? Binary search ile her karakter ~7 sorguda bulunur.$$,
    $$Çıktı kanalı tamamen yoksa: time-based blind. SLEEP(5) çağırırsın. Cevap geç gelirse koşul doğrudur. "Zaman" yeni kanal olur.$$
  ],
  $$Çıktı kanalı olmasa bile bilgi sızdırma yöntemleri olduğunu görmek. Boolean-based vs time-based ayrımını kavramak. Otomasyon (sqlmap) gerekliliği. WAF'ların neden bu durumu yakalamakta zorlandığı.$$,
  $$Blind SQLi'da çıktı yok. Boolean: ' AND SUBSTRING(password,1,1)='a — sayfa davranışı koşulu dolduruyor. Time: ' AND IF(SUBSTRING(...)='a',SLEEP(5),0). Karakter başına ~7 binary search sorgusu. Otomasyon: sqlmap --technique=B/T. Önlem: prepared statements + rate limit (sqlmap'i yavaşlatır ama tamamen engellemez).$$
),

(
  'sqli-error-based',
  'Error-based SQL Injection',
  'SQL Injection',
  'Zor',
  $$Bir uygulama veritabanı hata mesajlarını ekrana basıyor (geliştirme modu, generic 500 sayfası ayarlanmamış). Bu bilgi sızıntısının saldırgana sağladığı avantaj nedir, ve hata mesajını nasıl bir "veri çıkarma kanalına" çeviririz?$$,
  array[
    $$Bazı SQL fonksiyonları geçersiz girdiyle hata fırlatırken, hata mesajına girdinin parçasını gömer. MySQL'deki EXTRACTVALUE / UPDATEXML XPath fonksiyonları bunun klasik örneği.$$,
    $$Bir subquery sonucunu CONCAT ile bu fonksiyonun XPath argümanına yerleştirirsen, hata mesajının içinde subquery'nin sonucu görünür.$$,
    $$Pattern: extractvalue(1, concat('~', (SELECT version()))) — geçersiz XPath nedeniyle hata fırlar, mesaj içinde concat sonucu (DB versiyonu) görünür. Aynı tekniği SELECT ... FROM users ile genişletirsin.$$
  ],
  $$Error-based exfiltration: hata mesajı çıktı kanalı olarak kullanılabilir. Production'da neden generic hata mesajı zorunludur (defense-in-depth). Stack trace'lerin neden client'a sızmamalıdır.$$,
  $$EXTRACTVALUE/UPDATEXML gibi XPath fonksiyonları geçersiz format hatası fırlatırken concat'lenmiş subquery sonucunu hata mesajına gömer. Saldırgan mesajı response'tan parser. Önlem: prepared statements + production'da CUSTOM_ERROR_PAGE + DB error logging server-side, client'a sadece "Bir hata oluştu" döndür.$$
),

-- ─── Network Security ────────────────────────────────────────────────

(
  'net-port-scan',
  'Port Scan Analizi',
  'Network Security',
  'Kolay',
  $$Yetkili olduğun bir test sistemine nmap çalıştırdın:

nmap -sV target.lab

Sonuç: 22/tcp OpenSSH 7.2, 80/tcp Apache 2.4.7, 443/tcp Apache 2.4.7. Bu çıktı bir saldırgan veya pentester için ne kadar değerli bilgi içerir? Sıradaki adım ne olur?$$,
  array[
    $$Her açık port bir saldırı yüzeyi. Hangi servislerin çalıştığı ve hangi portta olduğu önemlidir.$$,
    $$Servis versiyonu kritik bir bilgi. Eski versiyonların bilinen güvenlik açıkları (CVE) olabilir.$$,
    $$"OpenSSH 7.2 CVE" araması yap. NVD (nvd.nist.gov) ve cve.mitre.org versiyona göre listelenmiş açıkları gösterir. Bulduğun CVE'nin CVSS skoru ne kadar yüksek?$$
  ],
  $$Pentest sürecinde reconnaissance fazının önemini kavramak. nmap flag'leri (-sV servis tespiti, -sS SYN scan, -O OS detection) farkları. CVE/CVSS sistemi. Banner grabbing'in neden devre dışı bırakılması gerektiği. IDS/IPS'in scan tespit etme mantığı.$$,
  $$nmap -sV servis versiyonu çıkarır, NVD/MITRE'de eşleşen CVE'ler aranır. Defense: minimum saldırı yüzeyi (sadece gerekli portlar), banner gizleme, fail2ban, IDS imzaları, port knocking. Etik not: scan sadece izinli sistemlerde, izinsiz scan birçok ülkede suç.$$
),

(
  'net-wireshark-pcap',
  'Wireshark Paket Analizi',
  'Network Security',
  'Orta',
  $$Eğitim laboratuvarında verilen bir pcap dosyasını inceliyorsun. İçinde HTTP trafiği var ve bir login isteği plaintext gönderilmiş (HTTPS değil). Wireshark'ta o paketi nasıl izole edersin? Bu trafiğin HTTPS üzerinden olmaması neden tehlikelidir?$$,
  array[
    $$Wireshark'ta üst kısımdaki "Display Filter" çubuğunu kullan. http.request.method == POST yazarsan sadece POST istekleri görünür.$$,
    $$Login formları genellikle POST gövdesinde "username", "password", "pwd" gibi parametreler taşır. Filtreleyip paket detayında "HTML Form URL Encoded" bölümüne bak.$$,
    $$Sağ tık > Follow > HTTP Stream — tüm konuşma akışını sırayla okuyabilirsin (request + response).$$
  ],
  $$Wireshark display filter syntax'ı. HTTP'nin neden plaintext olduğu için güvensiz olduğu. HTTPS/TLS'in handshake mantığı. HSTS header'ının amacı. Capture etiği: sadece izinli ağlarda paket yakalama yap.$$,
  $$HTTP plaintext olduğundan POST gövdesi pcap içinde okunabilir. Filter: http.request.method == POST. Right-click > Follow HTTP Stream. Önlem: HTTPS-only (HSTS preload), mixed content engelleme, secure cookie flag, modern uygulamalarda HTTP'ye redirect bile zayıflık (downgrade attack).$$
),

(
  'net-firewall-rules',
  'Firewall Kuralı Analizi',
  'Network Security',
  'Orta',
  $$Bir sunucunun iptables INPUT chain'inde şu kurallar var:

1. ALLOW tcp dport 22
2. ALLOW tcp dport 80
3. ALLOW tcp dport 443
4. DROP all

Default policy: ACCEPT. Bu yapılandırma görünüşte güvenli ama bir sorun var. Hangi senaryoda saldırgan beklemediğin bir porta bağlanabilir?$$,
  array[
    $$iptables kuralları yukarıdan aşağıya sırayla işlenir; ilk eşleşen kural uygulanır ve evaluation durur.$$,
    $$Hiçbir kurala eşleşmeyen paket ne olur? Burada default policy devreye girer.$$,
    $$Default policy ACCEPT + son kuralın "DROP all" olması ne tür edge case'lere yol açar? Yeni eklenen bir servis için ne olur?$$
  ],
  $$Stateful firewall mantığı, kural sırasının önemi, "deny by default" prensibi, default policy'nin neden DROP olması gerektiği, kuralların atomic değil sırayla uygulandığı, INPUT/OUTPUT/FORWARD chain ayrımı.$$,
  $$DROP all kuralı son sırada — ondan önceki ALLOW'lar match olursa DROP'a sıra gelmez (ki bu doğru). Ama default policy ACCEPT olduğu için: kural setini geçici flush edersen (iptables -F) tüm portlar açılır. Doğrusu: default policy DROP, sonra explicit ALLOW kuralları. "Fail-safe" prensibi.$$
),

(
  'net-arp-spoofing',
  'ARP Spoofing Tespit',
  'Network Security',
  'Zor',
  $$Yerel bir test ağında olağandışı yavaşlama var. Wireshark'ta ARP trafiğini incelediğinde, gateway IP'si (192.168.1.1) için iki farklı MAC adresinden ARP "is-at" cevabı geldiğini görüyorsun. Bu durum ne anlama gelir, neden tehlikelidir, hangi savunmalar etkilidir?$$,
  array[
    $$ARP protokolü 1982'de tasarlandı ve hiçbir authentication mekanizması yoktur — herkes ağa "ben bu IP'yim" diyebilir.$$,
    $$Aynı IP için farklı MAC'lerden cevap → cihazlardan en az biri yalan söylüyor. Saldırgan kendisini hangi cihaz gibi gösteriyor olabilir?$$,
    $$Saldırgan kendini gateway gibi tanıtırsa, ağdaki diğer cihazların trafiği saldırgan üzerinden geçer (MITM). Bu durumdan korunmak için Layer 2'de hangi mekanizmalar var?$$
  ],
  $$ARP protokolünün tasarım zayıflığı (no authentication). Layer 2 saldırılar. MITM tespit pattern'leri. Switch port security. Dynamic ARP Inspection (DAI). 802.1X port-based authentication. VPN/TLS'in neden Layer 2 saldırılara karşı son savunma olduğu.$$,
  $$ARP poisoning ile saldırgan kendi MAC'ini gateway IP'sine bağlar. Mağdur cihazların ARP cache'i zehirlenir, trafik saldırgana gider (MITM). Tespit: arpwatch, dual ARP responses, MAC değişim alarmları. Önlem: Static ARP entries (kritik sunucularda), DAI (managed switch'te), 802.1X, son katman olarak HTTPS/VPN.$$
),

-- ─── Linux ───────────────────────────────────────────────────────────

(
  'linux-file-permissions',
  'Dosya İzinleri',
  'Linux',
  'Kolay',
  $$ls -la çıktısında şunu görüyorsun:

-rwsr-xr-x  1 root root  84256 May 10  2024 /usr/bin/special_tool

Sahip izinleri "rws" — normal "x" yerine "s" var. Bu "s" ne anlama gelir, normal "x"'ten farkı nedir, ve güvenlik açısından neden dikkatli incelenmelidir?$$,
  array[
    $$"s" karakteri "x" yerine geçen özel bir bit. SUID (Set User ID) bit'i diye geçer.$$,
    $$SUID set olan bir program, kim çalıştırırsa çalıştırsın, dosyanın sahibinin yetkileriyle çalışır.$$,
    $$Sahibi root olan bir SUID binary'i, normal bir kullanıcı çalıştırınca root yetkileriyle çalışır. find / -perm -4000 ile sistemdeki tüm SUID binary'leri listeleyebilirsin. Hangileri "olmaması gereken" yerlerde?$$
  ],
  $$Linux izin modeli: rwx + special bits (SUID/SGID/sticky). Octal gösterim (4000 = SUID, 2000 = SGID, 1000 = sticky). SUID'in privilege escalation vektörü olarak rolü. find ile audit etme. GTFOBins kaynağının varlığı. Neden modern Linux SUID interpreter script'leri ignore eder.$$,
  $$SUID binary + root owner = potansiyel local privilege escalation. find / -perm -4000 -type f 2>/dev/null ile listele. GTFOBins (gtfobins.github.io) standart binary'lerin (vim, find, awk, less...) SUID iken nasıl shell açabileceğini listeler. Hardening: SUID bit'i sadece gerçekten gerekenlerde, capabilities (setcap) tercih et, AppArmor/SELinux ile sandbox.$$
),

(
  'linux-env-vars',
  'Environment Variables',
  'Linux',
  'Kolay',
  $$Bir CTF challenge'ında "bayrak environment variable içinde" deniyor. printenv komutu ne yapar? Hangi environment variable'lar güvenlik açısından kritiktir ve neden?$$,
  array[
    $$printenv parametre verilmezse tüm environment variable'ları listeler. printenv VAR_ADI ise sadece o değişkeni gösterir.$$,
    $$PATH değişkeni, kabuğun bir komut çağrıldığında onu hangi dizinlerde ve hangi sırayla arayacağını belirler.$$,
    $$PATH'te "." (current directory) veya yazılabilir bir dizin başlarda olursa, saldırgan aynı isimde kötü amaçlı komut yerleştirip orijinalin yerine çalıştırılmasını sağlayabilir. LD_PRELOAD ve LD_LIBRARY_PATH benzer dinamik kütüphane saldırılarına yol açar.$$
  ],
  $$Process ortamının çalışma davranışına etkisi. PATH hijacking. LD_PRELOAD / LD_LIBRARY_PATH ile kütüphane enjeksiyonu. sudo'nun env_reset davranışı ve env_keep ayarının riskleri. Kontrolsüz env değişkenlerinin saldırı yüzeyi olduğu.$$,
  $$env vars: PATH, LD_PRELOAD, LD_LIBRARY_PATH, IFS gibi değişkenler kod yükleme akışını değiştirir. PATH'e cwd veya /tmp koymak tehlikeli (PATH hijacking). LD_PRELOAD ile saldırgan kendi kütüphanesini yükletebilir (SUID'e karşı kernel filter). sudo varsayılan env_reset, env_keep listesine dikkat. Önlem: scriptlerde mutlak path, sudo/cron için sterilize edilmiş env.$$
),

(
  'linux-suid-exploit',
  'SUID Privilege Escalation Konsepti',
  'Linux',
  'Orta',
  $$Bir test sisteminde SUID bit'i set olmuş bir binary buldun:

-rwsr-xr-x  1 root root  /opt/log_reader

Bu program bir log dosyasını parametre olarak alıp ekrana basıyor. Saldırgan açısından bu durum hangi koşullar altında privilege escalation'a yol açabilir? Hangi soruları sormalısın?$$,
  array[
    $$Programın çalıştırdığı işlem root yetkisiyle çalışır. Programa hangi dosyaları okuttuğun program tasarımına bağlı.$$,
    $$Eğer program parametreyi yeterince doğrulamadan dosya açıyorsa, /etc/shadow gibi normalde okuyamayacağın dosyalara erişim olabilir. Ama daha derin bir tehlike daha var.$$,
    $$Program başka komutları çağırıyor mu? PATH'i mi kullanıyor (mutlak path yerine)? Kullandığı kütüphaneler nereden yükleniyor (LD_LIBRARY_PATH)? GTFOBins'te benzer binary'lere bak.$$
  ],
  $$SUID binary'lerin saldırı yüzeyi: input validation eksikliği, PATH-relative external command çağrıları, library injection riskleri. GTFOBins kaynağı. Modern Linux'un SUID interpreter script'lerini neden ignore ettiği (race condition tarihi). Capabilities ile fine-grained alternatif.$$,
  $$SUID + insufficient validation = privilege escalation. 1) Path traversal (log_reader ../../../etc/shadow). 2) PATH hijacking eğer external command çağırıyorsa. 3) LD_PRELOAD eğer kernel filter yoksa (genelde var). GTFOBins'te 300+ standart binary'nin SUID exploit'i listeli (vim :!sh, find -exec, awk 'BEGIN{system("/bin/sh")}'). Önlem: setuid yerine setcap (CAP_DAC_READ_SEARCH gibi), input validation, mutlak path, SUID'i denetim altında tut.$$
),

(
  'linux-cron-abuse',
  'Cron Job Privilege Escalation',
  'Linux',
  'Zor',
  $$/etc/crontab dosyasını okuyabiliyorsun ve şu satırı görüyorsun:

*/5 * * * *  root  /opt/scripts/backup.sh

Sonra script'in izinlerine bakıyorsun:

-rwxrwxrwx  1 root root  /opt/scripts/backup.sh

Bu yapılandırma neden kritik bir privilege escalation zafiyetidir? Saldırgan adım adım ne yapar?$$,
  array[
    $$cron tablo formatı: dakika saat gün ay haftaİçi user komut. Buradaki "root" kim olarak çalışacağını söyler.$$,
    $$Script'in izinleri 777 — herkes okuyabilir, yazabilir, çalıştırabilir. Kim "yazabilir"?$$,
    $$Saldırgan script içeriğine kendi komutunu eklerse (chmod +s /bin/bash gibi), 5 dakika içinde root yetkisiyle çalışır. Sonra ne yapar?$$
  ],
  $$crontab dosya formatı ve çalışma mantığı. World-writable dosyaların tehlikesi. Principle of least privilege. File permission hardening. Cron audit (ls -la /etc/cron.* + crontab -l). Linux post-exploitation enumeration script'lerinin (linpeas, linenum) ne taradığı.$$,
  $$777 + root cron = privilege escalation. Saldırgan: 1) backup.sh'a "chmod +s /bin/bash" veya "cp /bin/bash /tmp/r; chmod +s /tmp/r" ekler. 2) 5 dakika bekler. 3) /tmp/r -p ile root shell. Hardening: scripts root:root 755, cron job audit, /etc/cron.d/* izinleri sıkı, linpeas ile düzenli enumeration testi. Detection: file integrity monitoring (AIDE, tripwire).$$
),

-- ─── Cryptography ────────────────────────────────────────────────────

(
  'crypto-caesar',
  'Caesar Cipher',
  'Cryptography',
  'Kolay',
  $$Şifrelenmiş bir mesaj aldın:

  Khoor Gxqbd

Bu Caesar cipher (shift cipher) ile şifrelenmiş. Algoritma her harfi alfabede sabit bir sayı kadar kaydırır. Düz metni nasıl bulursun? Bu şifre neden modern güvenlik için yetersizdir?$$,
  array[
    $$Latin alfabesi 26 harf — yani sadece 25 olası farklı shift değeri var (0 hariç).$$,
    $$Brute-force basit: 25 shift'i tek tek dene, anlamlı bir kelime çıktığında durur. Online araçlar (cyberchef.org "ROT13/ROT47") otomatik yapar.$$,
    $$Daha akıllı yol: frequency analysis. İngilizce'de en sık harf "E" (~12.7%), Türkçe'de "A" (~12%). Şifreli metinde en sık geçen harfi say, dile göre eşle, shift'i hesapla.$$
  ],
  $$Substitution cipher prensibi. Brute-force vs frequency analysis ayrımı. Anahtar uzayının küçüklüğünün neden ölümcül olduğu. Modern simetrik şifrelerin (AES) anahtar uzayı (2^128, 2^256) ile karşılaştırma. Kerckhoffs prensibi (algoritma açık, sadece anahtar gizli olmalı).$$,
  $$"Khoor Gxqbd" = shift 3 geri = "Hello Dunya". 25 shift brute-force milisaniyede biter. Anahtar uzayı sadece 25, deneme sayısı küçük, frequency analysis bile gereksiz. Modern AES: anahtar uzayı 2^128 ≥ evrenin atom sayısının çok altında ama brute-force pratik olarak imkansız. Caesar sadece eğitim örneği, gerçek hayatta 0 güvenlik sağlar.$$
),

(
  'crypto-base-chain',
  'Encoding Zinciri',
  'Cryptography',
  'Kolay',
  $$Bir CTF flag aldın:

  VFZSQk1FNTNXSGM5

Tek seferde Base64 decode ettiğinde anlamlı bir şey çıkmıyor — yine encoding gibi görünen bir çıktı geliyor. Encoding'in birden fazla katman uygulanmış olabileceğini düşün. Yaklaşımın nasıl olmalı? Encoding ve encryption arasındaki fark nedir?$$,
  array[
    $$Base64 alfabesi A-Z a-z 0-9 + / karakterlerinden oluşur, sonunda "=" padding olabilir. Base32 sadece A-Z 2-7. Hex ise 0-9 a-f.$$,
    $$Bir kez decode et, çıkan şeye bak. Hala Base64'e benziyor mu? Base32 mi? Hex mi? Karakter setine bakarak hangi encoding olduğunu tahmin et.$$,
    $$CyberChef'te (cyberchef.org) "Magic" recipe çoklu katmanlı encoding'leri otomatik dener. Manuel yaparken: decode → karakter setine bak → tekrar decode. Encoding obfuscation'dur, şifreleme değil — anahtar gerekmez, herkes geri çevirebilir.$$
  ],
  $$Encoding (geri-dönüşülebilir, anahtar gerekmez) vs encryption (anahtar gerekli) ayrımı. Base64/Base32/Hex'in karakter set imzaları. Çoklu katman obfuscation pattern'i. CyberChef gibi araçların değeri. CTF çözümünde "encoding mi encryption mı" sorusunun ilk gelmesi.$$,
  $$VFZSQk1FNTNXSGM5 → Base64 decode → TZRBME53WGc5 → Base64 decode → MmA0nWXg= ... katman sayısı bilinmez ama her decode bir adım. Encoding güvenlik sağlamaz; rastgele görünmesi yeter sanılır ama obfuscation only. CyberChef Magic recipe maks 3-4 katmanı otomatik çözer. Eğitim noktası: production'da encoding asla "şifreleme" yerine kullanılmamalı.$$
),

(
  'crypto-xor',
  'XOR Şifreleme',
  'Cryptography',
  'Orta',
  $$Plaintext "HELLO" tek-byte XOR key ile şifrelenmiş. Şifreli metin (hex):

  10 1D 10 10 13

Hangi byte key kullanıldı? XOR'un hangi matematiksel özelliği bu çözümü mümkün kılar? Tek byte key neden gerçek hayatta tehlikeli, OTP (one-time pad) neden farklı?$$,
  array[
    $$XOR'un kritik özelliği: A XOR A = 0, ve A XOR B XOR B = A. Yani "kendisinin tersi". Şifreleme = decryption.$$,
    $$plaintext[0] XOR key = ciphertext[0]. plaintext'in ilk karakterini biliyorsun (H). Bunu kullanabilirsin.$$,
    $$H'nin ASCII değeri 0x48. ciphertext[0] = 0x10. 0x10 XOR 0x48 hesapla — bu key'in ta kendisidir. Kontrol için diğer karakterlerle de doğrula.$$
  ],
  $$XOR'un involutif (kendisinin tersi) özelliği. Known-plaintext attack mantığı. Key uzayı vs anahtar entropisi farkı. Tek byte XOR'da 256 olası key — brute force 1 ms. OTP'nin gerçek güvenliği için anahtar gereksinimleri (rastgele, plaintext kadar uzun, asla yeniden kullanılmaz, gizli).$$,
  $$Key = 'H' XOR 0x10 = 0x48 XOR 0x10 = 0x58 = 'X'. Doğrula: 'E' XOR 'X' = 0x45 XOR 0x58 = 0x1D ✓. Tek byte XOR = 256 key brute-force, 1 ms. Known plaintext varsa anında çözülür. OTP teorik olarak unbreakable AMA: anahtar dağıtımı zor (anahtar zaten plaintext kadar büyük, neden sadece onu paylaşmıyorsun?), key reuse felaket (Venona Project tarihçesi). Modern: AES-GCM gibi authenticated encryption.$$
),

(
  'crypto-hash-collision',
  'Hash Çakışması Konsepti',
  'Cryptography',
  'Orta',
  $$MD5 hash fonksiyonu hala bazı eski sistemlerde kullanılıyor (özellikle dosya bütünlük checksumlarında). 2004'ten beri ciddi zafiyetleri biliniyor. "Hash collision" tam olarak nedir, neden saldırgan için değerli, ve modern bir uygulama hangi hash'leri kullanmalı?$$,
  array[
    $$Hash fonksiyonu sınırsız büyüklükteki girdiyi sabit boyutta çıktıya (MD5 = 128 bit) eşler. İki farklı girdinin aynı hash'i çıkması mümkün mü?$$,
    $$Pigeonhole prensibi: sınırsız girdi → sınırlı çıktı means kaçınılmaz olarak en az iki farklı girdi aynı çıktıya gider. Önemli olan bunu BULMAK ne kadar zor?$$,
    $$Saldırgan iki farklı dosya hazırlasa, ikisinin de MD5'i aynı çıksa: birisi imzalanır (örn. yazılım sertifikası), diğeri kullanılır (kötü amaçlı yazılım). Mağdur hash'i doğrularken tehlikeyi göremez. MD5'te bu saldırı dakikalar içinde mümkün. SHA-256, SHA-3, BLAKE3 hala dirençli.$$
  ],
  $$Hash fonksiyonu temel özellikler: deterministic, fixed output, preimage resistance, second-preimage resistance, collision resistance. MD5 ve SHA-1'in neden deprecated olduğu (chosen-prefix collision dakikalarda). Modern hash önerileri: SHA-256, SHA-3, BLAKE3. Şifre hash'leme için ayrı sınıf: bcrypt/argon2/scrypt (yavaş + tuzlu).$$,
  $$Collision: H(a) = H(b), a ≠ b. MD5'te chosen-prefix collision Stevens et al. 2007'den beri pratik. Saldırgan iki PDF/x509 sertifika hazırlar — biri imzalanır CA tarafından, diğeri swap edilir. Modern güvenlik: SHA-256 minimum, SHA-3 gelecek-uyumlu. ÖNEMLİ ayrım: dosya checksum için SHA-256 yeterli, şifre saklamak için ASLA — bcrypt/argon2 (slow + memory-hard + tuzlu) zorunlu.$$
)

on conflict (slug) do nothing;
