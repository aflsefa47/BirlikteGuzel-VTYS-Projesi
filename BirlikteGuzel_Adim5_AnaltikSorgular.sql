-- =============================================
-- BİRLİKTE GÜZEL — Adım 5: Analitik Sorgular
-- 3 Farklı Karmaşık Sorgu Senaryosu
-- =============================================
USE BirlikteGuzel;
GO


-- =============================================================================
-- SORGU 1: JOIN — Detaylı Sipariş Fişi Raporu (6 Tablo Birleştirme)
-- =============================================================================
-- 
-- İŞ İHTİYACI: 
--   Bir yönetici "Teslim edilen tüm siparişlerin detaylı fişini görmek
--   istiyorum: Kim sipariş verdi, hangi restorandan, hangi kurye teslim
--   etti, hangi yemeklerden kaçar adet aldı ve her kalemin tutarı ne?"
--   dediğinde bu sorgu çalıştırılır.
--
-- BİRLEŞTİRİLEN TABLOLAR:
--   1) Orders         → Sipariş ana bilgileri (tarih, durum, ödeme)
--   2) Customers      → Müşteri adı
--   3) Restaurants     → Restoran adı
--   4) Couriers        → Kurye adı
--   5) OrderDetails    → Sipariş kalemleri (adet, birim fiyat)
--   6) MenuItems       → Yemek isimleri
--
-- NEDEN 6 TABLO?
--   Veriler 3NF gereği ayrı tablolarda tutulur (veri tekrarı yok).
--   Anlamlı bir rapor için bu tabloların birleştirilmesi gerekir.
-- =============================================================================

SELECT 
    o.OrderID                           AS [Sipariş No],
    c.FirstName + ' ' + c.LastName      AS [Müşteri],
    r.Name                              AS [Restoran],
    ISNULL(k.FirstName, N'Atanmadı')    AS [Kurye],
    m.ItemName                          AS [Yemek],
    od.Quantity                         AS [Adet],
    od.UnitPrice                        AS [Birim Fiyat (₺)],
    od.LineTotal                        AS [Satır Toplam (₺)],
    o.TotalAmount                       AS [Sipariş Toplam (₺)],
    o.Status                            AS [Durum],
    o.PaymentMethod                     AS [Ödeme],
    -- FORMAT: Tarihi Türkçe okunabilir formata çevirir.
    FORMAT(o.OrderDate, 'dd.MM.yyyy HH:mm')  AS [Tarih]
FROM Orders o
    INNER JOIN Customers    c  ON o.CustomerID    = c.CustomerID
    INNER JOIN Restaurants  r  ON o.RestaurantID  = r.RestaurantID
    -- LEFT JOIN: Kurye atanmamış siparişler de görünsün.
    LEFT JOIN  Couriers     k  ON o.CourierID     = k.CourierID
    INNER JOIN OrderDetails od ON o.OrderID       = od.OrderID
    INNER JOIN MenuItems    m  ON od.MenuItemID   = m.MenuItemID
WHERE o.IsActive = 1
-- ORDER BY: Siparişler tarih sırasına göre, her sipariş içinde kalemler sıralı.
ORDER BY o.OrderDate, o.OrderID, od.OrderDetailID;
GO


-- =============================================================================
-- SORGU 2: GROUP BY + HAVING — Restoran Performans Analizi
-- =============================================================================
--
-- İŞ İHTİYACI:
--   Platform yöneticisi şunu soruyor: "Her restoranın toplam kaç siparişi
--   var, toplam cirosu ne, ortalama sipariş tutarı kaç TL? Sadece 300 TL 
--   üzerinde ciro yapan restoranları göster."
--
-- KULLANILAN KAVRAMLAR:
--   COUNT()   → Sipariş sayısını hesaplar
--   SUM()     → Toplam ciroyu hesaplar
--   AVG()     → Ortalama sipariş tutarını hesaplar
--   MAX()     → En yüksek sipariş tutarını bulur
--   GROUP BY  → Verileri restoran bazında gruplar
--   HAVING    → Gruplama SONRASI filtreleme yapar
--
-- HAVING vs WHERE FARKI:
--   WHERE  → Gruplama ÖNCESİ tek tek satırları filtreler
--   HAVING → Gruplama SONRASI grup toplamlarını filtreler
--   Örnek: WHERE ile "iptal olmayan siparişleri al",
--          HAVING ile "cirosu 300'den fazla olan restoranları göster"
-- =============================================================================

SELECT 
    r.Name                                      AS [Restoran],
    COUNT(o.OrderID)                             AS [Toplam Sipariş],
    -- CAST + ROUND: Para değerlerini düzgün formatta gösterir.
    CAST(SUM(o.TotalAmount) AS DECIMAL(10,2))    AS [Toplam Ciro (₺)],
    CAST(AVG(o.TotalAmount) AS DECIMAL(10,2))    AS [Ort. Sipariş (₺)],
    CAST(MAX(o.TotalAmount) AS DECIMAL(10,2))    AS [En Yüksek Sipariş (₺)],
    -- MIN-MAX tarih aralığı: Restoranın ne zamandan beri sipariş aldığını gösterir.
    FORMAT(MIN(o.OrderDate), 'dd.MM.yyyy')       AS [İlk Sipariş],
    FORMAT(MAX(o.OrderDate), 'dd.MM.yyyy')       AS [Son Sipariş]
FROM Restaurants r
    -- LEFT JOIN: Hiç siparişi olmayan restoranlar da listede görünsün.
    LEFT JOIN Orders o ON r.RestaurantID = o.RestaurantID
                      AND o.Status = N'Teslim Edildi'  -- Sadece teslim edilenler
                      AND o.IsActive = 1
WHERE r.IsActive = 1
-- GROUP BY: Her restoran için ayrı bir satır oluşturur.
GROUP BY r.Name
-- HAVING: Gruplama sonrası filtreleme.
-- Toplam cirosu 300 TL'den fazla olan restoranları gösterir.
-- Bu filtreyi WHERE'e yazamazdık çünkü SUM() bir agrega fonksiyonudur.
HAVING SUM(o.TotalAmount) > 300
-- Ciroya göre büyükten küçüğe sırala.
ORDER BY [Toplam Ciro (₺)] DESC;
GO


-- =============================================================================
-- SORGU 3: SUBQUERY (Alt Sorgu) — Bağış Yapan Müşterilerin Sipariş Analizi
-- =============================================================================
--
-- İŞ İHTİYACI:
--   "Askıda yemek bağışı yapan müşterilerimiz platformda sipariş de
--   veriyor mu? Eğer veriyorsa toplam ne kadar harcama yapmışlar?"
--   Bu analiz, bağışçı profili çıkarmak için önemlidir.
--
-- KULLANILAN KAVRAMLAR:
--   IN + Subquery  → Ana sorgudaki verileri alt sorguyla filtreler
--   EXISTS         → "Var mı?" kontrolü yapar (performanslı)
--
-- IN vs EXISTS FARKI:
--   IN     → Alt sorgunun döndürdüğü DEĞERLER LİSTESİNDE arar
--   EXISTS → Alt sorguda en az bir satır VAR MI diye kontrol eder
--   Küçük listelerde IN, büyük tablolarda EXISTS daha performanslıdır.
-- =============================================================================

-- Yöntem A: IN ile Alt Sorgu
-- "Bağış yapan müşteri ID'lerini bul, bu ID'lere sahip müşterilerin 
-- sipariş özetini getir"
SELECT 
    c.FirstName + ' ' + c.LastName     AS [Müşteri],
    COUNT(o.OrderID)                    AS [Sipariş Sayısı],
    ISNULL(SUM(o.TotalAmount), 0)       AS [Toplam Harcama (₺)],
    -- Alt sorgu ile bağış sayısını da aynı satırda göster.
    -- Bu bir SCALAR SUBQUERY'dir → tek değer döner.
    (SELECT COUNT(*) 
     FROM SuspendedFoodDonations d 
     WHERE d.DonorCustomerID = c.CustomerID 
       AND d.IsActive = 1)              AS [Bağış Sayısı]
FROM Customers c
    LEFT JOIN Orders o ON c.CustomerID = o.CustomerID 
                       AND o.IsActive = 1
-- IN Subquery: Sadece en az bir bağış yapmış müşterileri filtreler.
-- Alt sorgu önce çalışır → bağışçı ID listesini döner → ana sorgu filtreler.
WHERE c.CustomerID IN (
    SELECT DonorCustomerID 
    FROM SuspendedFoodDonations 
    WHERE IsActive = 1
)
GROUP BY c.CustomerID, c.FirstName, c.LastName
ORDER BY [Toplam Harcama (₺)] DESC;
GO

-- Yöntem B: EXISTS ile Alt Sorgu (Aynı sonuç, farklı yaklaşım)
-- "Her müşteri için, eğer bağış kaydı VARSA onu getir"
SELECT 
    c.FirstName + ' ' + c.LastName      AS [Müşteri],
    c.Email                              AS [E-posta],
    -- Correlated Subquery: Dış sorgunun her satırı için çalışır.
    (SELECT COUNT(*) 
     FROM Orders o 
     WHERE o.CustomerID = c.CustomerID 
       AND o.IsActive = 1)               AS [Sipariş Sayısı],
    (SELECT ISNULL(SUM(o.TotalAmount), 0) 
     FROM Orders o 
     WHERE o.CustomerID = c.CustomerID 
       AND o.Status = N'Teslim Edildi' 
       AND o.IsActive = 1)               AS [Toplam Harcama (₺)]
FROM Customers c
-- EXISTS: Alt sorgu en az bir satır dönerse TRUE olur.
-- IN'den farkı: Değer karşılaştırması yerine "varlık kontrolü" yapar.
-- Büyük tablolarda EXISTS daha hızlıdır çünkü ilk eşleşmede durur.
WHERE EXISTS (
    SELECT 1 
    FROM SuspendedFoodDonations d 
    WHERE d.DonorCustomerID = c.CustomerID 
      AND d.IsActive = 1
);
GO


-- =============================================================================
-- BONUS: Karmaşık Alt Sorgu — Hiç Sipariş Verilmemiş Menü Kalemleri
-- =============================================================================
--
-- İŞ İHTİYACI:
--   "Menüde olup da hiç sipariş edilmemiş ürünler hangileri?
--   Bu ürünleri menüden kaldırmalı mıyız?"
--
-- NOT EXISTS: "Eşleşen kayıt YOKSA getir" mantığı.
-- =============================================================================

SELECT 
    r.Name       AS [Restoran],
    m.ItemName   AS [Yemek],
    m.Price      AS [Fiyat (₺)]
FROM MenuItems m
    INNER JOIN Restaurants r ON m.RestaurantID = r.RestaurantID
WHERE m.IsActive = 1
  -- NOT EXISTS: Bu menü kalemine ait hiç sipariş detayı yoksa TRUE döner.
  AND NOT EXISTS (
      SELECT 1 
      FROM OrderDetails od 
      WHERE od.MenuItemID = m.MenuItemID 
        AND od.IsActive = 1
  )
ORDER BY r.Name, m.ItemName;
GO

PRINT N'';
PRINT N'✅ Adım 5 tamamlandı! 3 analitik sorgu + 1 bonus sorgu çalıştırıldı.';
GO
