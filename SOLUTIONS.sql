-- ============================================================
--  SOLUTIONS.sql
--  Telco Project - i2i Systems
--  Oracle XE
-- ============================================================


-- ============================================================
-- 1. TARİFE BAZLI MÜŞTERİ SORGULARI
-- ============================================================

-- ------------------------------------------------------------
-- 1.1 'Kobiye Destek' tarifesine abone olan müşterileri listele
-- ------------------------------------------------------------
/*
  YAKLAŞIM:
  CUSTOMERS tablosunu TARIFFS tablosuyla TARIFF_ID üzerinden JOIN yapıyoruz.
  WHERE koşulunda tarife adını 'Kobiye Destek' olarak filtreliyoruz.
  Bu sayede tarife ID'sini hard-code etmeden, isim bazlı esnek bir sorgu elde ediyoruz.
  Sonuçları müşteri adına göre alfabetik sıralıyoruz.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE t.NAME = 'Kobiye Destek'
ORDER BY c.NAME;


-- ------------------------------------------------------------
-- 1.2 Bu tarifeye en son abone olan müşteriyi bul
-- ------------------------------------------------------------
/*
  YAKLAŞIM:
  'Kobiye Destek' tarifesindeki müşteriler arasından SIGNUP_DATE'i
  en büyük (en yeni tarihli) olanı bulmamız gerekiyor.
  MAX(SIGNUP_DATE) ile en son tarihi buluyoruz ve bunu WHERE koşuluna
  koyarak o tarihe sahip müşteri(ler)i getiriyoruz.
  Aynı tarihte birden fazla kişi kayıt olmuş olabileceğinden
  tek satır döneceği garanti edilemez; bu yüzden ROWNUM ile kesme yapmıyoruz.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE t.NAME = 'Kobiye Destek'
  AND c.SIGNUP_DATE = (
      SELECT MAX(c2.SIGNUP_DATE)
      FROM CUSTOMERS c2
      JOIN TARIFFS t2 ON c2.TARIFF_ID = t2.TARIFF_ID
      WHERE t2.NAME = 'Kobiye Destek'
  );


-- ============================================================
-- 2. TARİFE DAĞILIMI
-- ============================================================

-- ------------------------------------------------------------
-- 2.1 Müşteriler arasındaki tarife dağılımını bul
-- ------------------------------------------------------------
/*
  YAKLAŞIM:
  CUSTOMERS tablosunu TARIFFS ile JOIN yaparak her tarife için
  abone sayısını COUNT(*) ile hesaplıyoruz.
  GROUP BY ile tarife bazında gruplama yapıyoruz.
  Yüzdelik oran da ekliyoruz; bu, toplam müşteri sayısına bölünerek hesaplanıyor.
  Sonuçları abone sayısına göre azalan sırada döndürüyoruz.
*/
SELECT
    t.NAME                                              AS TARIFF_NAME,
    t.MONTHLY_FEE,
    COUNT(c.CUSTOMER_ID)                               AS SUBSCRIBER_COUNT,
    ROUND(COUNT(c.CUSTOMER_ID) * 100.0 /
          (SELECT COUNT(*) FROM CUSTOMERS), 2)         AS PERCENTAGE
FROM TARIFFS t
LEFT JOIN CUSTOMERS c ON t.TARIFF_ID = c.TARIFF_ID
GROUP BY t.TARIFF_ID, t.NAME, t.MONTHLY_FEE
ORDER BY SUBSCRIBER_COUNT DESC;


-- ============================================================
-- 3. MÜŞTERİ KAYIT TARİHİ ANALİZİ
-- ============================================================

-- ------------------------------------------------------------
-- 3.1 En erken kaydolan müşterileri bul
-- ------------------------------------------------------------
/*
  YAKLAŞIM:
  Önce MIN(SIGNUP_DATE) subquery'siyle sistemdeki en eski kayıt tarihini buluyoruz.
  Ardından bu tarihle eşleşen tüm müşterileri getiriyoruz.
  NOT: En eski müşteriler en düşük CUSTOMER_ID'ye sahip olmayabilir; ID ataması
  kayıt tarihinden bağımsız olabilir. Bu yüzden tarih bazlı filtreleme yapıyoruz.
  Hint'in bu noktaya dikkat çektiğini göz önünde bulundurarak ID yerine DATE kullandık.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE,
    t.NAME AS TARIFF_NAME
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE c.SIGNUP_DATE = (SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS)
ORDER BY c.CUSTOMER_ID;


-- ------------------------------------------------------------
-- 3.2 Bu en erken müşterilerin şehirlere göre dağılımı
-- ------------------------------------------------------------
/*
  YAKLAŞIM:
  3.1'deki sorguyu CTE (Common Table Expression) olarak tanımlıyoruz;
  bu sayede kodun okunabilirliği artıyor ve aynı subquery'yi tekrarlamamıza gerek kalmıyor.
  En erken müşteri kümesini CTE ile çektikten sonra
  CITY'ye göre GROUP BY yaparak her şehirdeki müşteri sayısını buluyoruz.
  Sonuçları müşteri sayısına göre azalan sırada döndürüyoruz.
*/
WITH EARLIEST_CUSTOMERS AS (
    SELECT CITY
    FROM CUSTOMERS
    WHERE SIGNUP_DATE = (SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS)
)
SELECT
    CITY,
    COUNT(*) AS CUSTOMER_COUNT
FROM EARLIEST_CUSTOMERS
GROUP BY CITY
ORDER BY CUSTOMER_COUNT DESC;


-- ============================================================
-- 4. EKSİK AYLIK KAYITLAR
-- ============================================================

-- ------------------------------------------------------------
-- 4.1 Aylık kaydı eksik olan müşterilerin ID'lerini bul
-- ------------------------------------------------------------
/*
  YAKLAŞIM:
  Her müşterinin MONTHLY_STATS tablosunda bir kaydı olması gerekiyor.
  NOT IN ya da NOT EXISTS ile CUSTOMERS'daki tüm ID'leri MONTHLY_STATS'daki
  CUSTOMER_ID listesiyle karşılaştırıyoruz.
  NOT EXISTS genellikle büyük veri setlerinde NOT IN'e göre daha performanslıdır
  çünkü NULL değerlerini daha güvenli işler ve index kullanımı daha etkilidir.
  Bu yüzden NOT EXISTS tercih ettik.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME AS TARIFF_NAME
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE NOT EXISTS (
    SELECT 1
    FROM MONTHLY_STATS ms
    WHERE ms.CUSTOMER_ID = c.CUSTOMER_ID
)
ORDER BY c.CUSTOMER_ID;


-- ------------------------------------------------------------
-- 4.2 Eksik müşterilerin şehirlere göre dağılımı
-- ------------------------------------------------------------
/*
  YAKLAŞIM:
  4.1'deki mantığı yeniden kullanarak eksik müşterileri bir CTE içinde tanımlıyoruz.
  Ardından bu müşterileri CITY bazında gruplayarak her şehirde kaç kişinin
  aylık kaydının eksik olduğunu hesaplıyoruz.
  Şehir bazlı dağılımı bilmek, veri girişi sorunlarının belirli bölgelere
  mi yoksa rastgele mi dağıldığını anlamaya yardımcı olur.
*/
WITH MISSING_CUSTOMERS AS (
    SELECT c.CITY
    FROM CUSTOMERS c
    WHERE NOT EXISTS (
        SELECT 1
        FROM MONTHLY_STATS ms
        WHERE ms.CUSTOMER_ID = c.CUSTOMER_ID
    )
)
SELECT
    CITY,
    COUNT(*) AS MISSING_COUNT
FROM MISSING_CUSTOMERS
GROUP BY CITY
ORDER BY MISSING_COUNT DESC;


-- ============================================================
-- 5. KULLANIM ANALİZİ
-- ============================================================

-- ------------------------------------------------------------
-- 5.1 Veri limitinin en az %75'ini kullanan müşteriler
-- ------------------------------------------------------------
/*
  YAKLAŞIM:
  CUSTOMERS -> TARIFFS -> MONTHLY_STATS üç tablosunu JOIN yapıyoruz.
  DATA_LIMIT'i 0 olan tarifeleri (Kurumsal SMS: sadece SMS paketi) hariç tutuyoruz
  çünkü bu tarifeler için veri kullanım oranı hesaplanamaz (sıfıra bölme hatası).
  DATA_USAGE / DATA_LIMIT >= 0.75 koşuluyla %75 eşiğini uyguluyoruz.
  Kullanım yüzdesini de sonuçta gösteriyoruz.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME                                              AS TARIFF_NAME,
    ms.DATA_USAGE,
    t.DATA_LIMIT,
    ROUND(ms.DATA_USAGE / t.DATA_LIMIT * 100, 2)       AS DATA_USAGE_PCT
FROM CUSTOMERS c
JOIN TARIFFS t      ON c.TARIFF_ID     = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID = ms.CUSTOMER_ID
WHERE t.DATA_LIMIT > 0
  AND ms.DATA_USAGE / t.DATA_LIMIT >= 0.75
ORDER BY DATA_USAGE_PCT DESC;


-- ------------------------------------------------------------
-- 5.2 Tüm paket limitlerini (data, dakika, SMS) bitiren müşteriler
-- ------------------------------------------------------------
/*
  YAKLAŞIM:
  Bir müşterinin tüm limitlerini tüketmiş sayılması için DATA_USAGE >= DATA_LIMIT,
  MINUTE_USAGE >= MINUTE_LIMIT ve SMS_USAGE >= SMS_LIMIT koşullarının
  aynı anda sağlanması gerekiyor.
  DATA_LIMIT = 0 olan tarifeler (ör. Kurumsal SMS) için veri kontrolü atlanmalı;
  bu yüzden CASE WHEN ile 0 limitli kategorileri ayrıca ele alıyoruz.
  Böylece yalnızca ilgili limitlere sahip olan kategoriler kontrol ediliyor.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME          AS TARIFF_NAME,
    ms.DATA_USAGE,  t.DATA_LIMIT,
    ms.MINUTE_USAGE, t.MINUTE_LIMIT,
    ms.SMS_USAGE,   t.SMS_LIMIT
FROM CUSTOMERS c
JOIN TARIFFS t        ON c.TARIFF_ID     = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID   = ms.CUSTOMER_ID
WHERE
    (t.DATA_LIMIT   = 0 OR ms.DATA_USAGE   >= t.DATA_LIMIT)
    AND (t.MINUTE_LIMIT = 0 OR ms.MINUTE_USAGE >= t.MINUTE_LIMIT)
    AND (t.SMS_LIMIT    = 0 OR ms.SMS_USAGE    >= t.SMS_LIMIT)
ORDER BY c.CUSTOMER_ID;


-- ============================================================
-- 6. ÖDEME ANALİZİ
-- ============================================================

-- ------------------------------------------------------------
-- 6.1 Ödemesi yapılmamış müşterileri bul
-- ------------------------------------------------------------
/*
  YAKLAŞIM:
  MONTHLY_STATS tablosunda PAYMENT_STATUS = 'UNPAID' olan kayıtları filtreliyoruz.
  CUSTOMERS ve TARIFFS ile JOIN yaparak müşteri detaylarını ve tarife bilgilerini
  sonuçlara ekliyoruz; bu, hangi tarifenin ödenmemiş faturasının daha fazla olduğunu
  görmek açısından da faydalıdır.
  Sonuçları şehre ve müşteri adına göre sıralıyoruz.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME          AS TARIFF_NAME,
    t.MONTHLY_FEE,
    ms.PAYMENT_STATUS
FROM CUSTOMERS c
JOIN TARIFFS t        ON c.TARIFF_ID     = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID   = ms.CUSTOMER_ID
WHERE ms.PAYMENT_STATUS = 'UNPAID'
ORDER BY c.CITY, c.NAME;


-- ------------------------------------------------------------
-- 6.2 Tüm ödeme durumlarının tarifelere göre dağılımı
-- ------------------------------------------------------------
/*
  YAKLAŞIM:
  Ödeme durumu (PAYMENT_STATUS) ve tarife adı (TARIFF NAME) bazında gruplama yaparak
  her kombinasyondaki müşteri sayısını buluyoruz.
  PIVOT benzeri bir görünüm için satırları COUNT ile özetliyoruz.
  Hem tarife hem de ödeme durumu bazında toplam satır göstermek için
  ORDER BY ile okunabilirliği artırıyoruz.
  Bu dağılım, hangi tarifede ödeme sorunlarının daha fazla olduğunu analiz etmemize olanak tanır.
*/
SELECT
    t.NAME                  AS TARIFF_NAME,
    ms.PAYMENT_STATUS,
    COUNT(*)                AS COUNT,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY t.NAME), 2) AS PCT_WITHIN_TARIFF
FROM MONTHLY_STATS ms
JOIN CUSTOMERS c ON ms.CUSTOMER_ID = c.CUSTOMER_ID
JOIN TARIFFS t   ON c.TARIFF_ID    = t.TARIFF_ID
GROUP BY t.NAME, ms.PAYMENT_STATUS
ORDER BY t.NAME, ms.PAYMENT_STATUS;
