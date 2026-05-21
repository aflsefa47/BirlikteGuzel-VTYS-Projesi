-- =============================================
-- BİRLİKTE GÜZEL — Adım 4: Programlanabilirlik Nesneleri
-- View'lar, Trigger'lar ve Index'ler
-- =============================================
USE BirlikteGuzel;
GO

-- =============================================================================
-- ========================  VIEW'LAR (Görünümler)  ============================
-- =============================================================================

-- =============================================
-- VIEW 1: vw_SiparisDetayRaporu
-- Amaç: Sipariş fişi gibi detaylı bilgi sunar.
--        3 tabloyu (Orders + Customers + Restaurants) birleştirir.
--        Her sorguda tekrar tekrar JOIN yazmak yerine
--        bu view'dan tek satırla çekilir.
-- =============================================
CREATE VIEW vw_SiparisDetayRaporu AS
SELECT
    o.OrderID                          AS SiparisNo,
    c.FirstName + ' ' + c.LastName     AS MusteriAdi,
    c.Phone                            AS MusteriTelefon,
    r.Name                             AS RestoranAdi,
    -- ISNULL: Kurye henüz atanmamışsa (NULL) "Atanmadı" yazar.
    -- NULL değer ekranda boş görünür, kullanıcı karışıklığı önlenir.
    ISNULL(k.FirstName, N'Atanmadı')   AS KuryeAdi,
    o.OrderDate                        AS SiparisTarihi,
    o.Status                           AS Durum,
    o.PaymentMethod                    AS OdemeYontemi,
    o.TotalAmount                      AS ToplamTutar
FROM Orders o
    -- INNER JOIN: Sadece eşleşen kayıtları getirir.
    -- Her siparişin mutlaka bir müşterisi ve restoranı vardır (NOT NULL FK).
    INNER JOIN Customers   c ON o.CustomerID   = c.CustomerID
    INNER JOIN Restaurants r ON o.RestaurantID = r.RestaurantID
    -- LEFT JOIN: Kurye henüz atanmamış olabilir (CourierID NULL).
    -- INNER JOIN kullansaydık kuryesiz siparişler hiç görünmezdi.
    LEFT JOIN  Couriers    k ON o.CourierID    = k.CourierID
WHERE o.IsActive = 1;
GO

-- =============================================
-- VIEW 2: vw_AskidaYemekHavuzu
-- Amaç: Askıda yemek havuzunun güncel durumunu gösterir.
--        Hangi yemekten kaç adet kaldığını, hangi restorandan
--        olduğunu ve bağışçı bilgisini (anonim değilse) sunar.
--        4 tabloyu birleştirir.
-- =============================================
CREATE VIEW vw_AskidaYemekHavuzu AS
SELECT
    di.DonationItemID                AS KalemID,
    -- CASE WHEN: Bağışçı "anonim" seçtiyse adı gizlenir.
    -- Bu iş kuralı veritabanı katmanında uygulanır,
    -- uygulama katmanına güvenmek yerine veri güvenliği sağlanır.
    CASE 
        WHEN d.IsAnonymous = 1 THEN N'Anonim Bağışçı'
        ELSE c.FirstName + ' ' + c.LastName 
    END                              AS BagisciAdi,
    r.Name                           AS RestoranAdi,
    m.ItemName                       AS YemekAdi,
    m.Price                          AS BirimFiyat,
    di.Quantity                      AS BagislananAdet,
    di.RemainingQty                  AS KalanAdet,
    d.DonationDate                   AS BagisTarihi
FROM DonationItems di
    INNER JOIN SuspendedFoodDonations d ON di.DonationID  = d.DonationID
    INNER JOIN Customers              c ON d.DonorCustomerID = c.CustomerID
    INNER JOIN MenuItems              m ON di.MenuItemID  = m.MenuItemID
    INNER JOIN Restaurants            r ON m.RestaurantID = r.RestaurantID
WHERE di.IsActive = 1
  AND di.RemainingQty > 0;  -- Sadece havuzda hâlâ yemek kalan kalemleri göster
GO


-- =============================================================================
-- ========================  TRIGGER'LAR (Tetikleyiciler)  =====================
-- =============================================================================

-- =============================================
-- TRIGGER 1: trg_CiroGuncelle
-- Tablo: Orders (AFTER INSERT, UPDATE)
-- Amaç: Sipariş "Teslim Edildi" olduğunda restoranın
--        TotalRevenue alanını otomatik günceller.
--
-- Ne zaman tetiklenir?
--   1) Yeni sipariş "Teslim Edildi" olarak eklendiğinde (INSERT)
--   2) Mevcut siparişin durumu "Teslim Edildi"ye değiştiğinde (UPDATE)
--   3) "Teslim Edildi" olan sipariş "İptal" edildiğinde (cirodan düşer)
--
-- Neden trigger?
--   Her seferinde SUM() ile ciro hesaplamak yerine önceden
--   hesaplanmış değeri güncellemek daha performanslıdır.
-- =============================================
CREATE TRIGGER trg_CiroGuncelle
ON Orders
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- DURUM 1: Yeni "Teslim Edildi" siparişi → ciroya EKLE
    -- inserted tablosu: INSERT veya UPDATE sonrası yeni değerleri tutar.
    UPDATE Restaurants
    SET TotalRevenue = TotalRevenue + i.TotalAmount
    FROM Restaurants r
        INNER JOIN inserted i ON r.RestaurantID = i.RestaurantID
    WHERE i.Status = N'Teslim Edildi'
      -- deleted tablosu: UPDATE öncesi eski değerleri tutar.
      -- INSERT işleminde deleted boştur, bu yüzden NOT EXISTS ile kontrol edilir.
      -- Bu koşul, zaten "Teslim Edildi" olan bir siparişin tekrar sayılmasını engeller.
      AND NOT EXISTS (
          SELECT 1 FROM deleted d 
          WHERE d.OrderID = i.OrderID 
            AND d.Status = N'Teslim Edildi'
      );

    -- DURUM 2: "Teslim Edildi" olan sipariş iptal edildi → cirodan DÜŞ
    UPDATE Restaurants
    SET TotalRevenue = TotalRevenue - d.TotalAmount
    FROM Restaurants r
        INNER JOIN deleted d ON r.RestaurantID = d.RestaurantID
        INNER JOIN inserted i ON d.OrderID = i.OrderID
    WHERE d.Status = N'Teslim Edildi'
      AND i.Status = N'İptal';
END;
GO

-- =============================================
-- TRIGGER 2: trg_BagisKalanGuncelle
-- Tablo: SuspendedFoodClaims (AFTER INSERT)
-- Amaç: İhtiyaç sahibi havuzdan yemek aldığında:
--   1) Günlük 2 talep limitini kontrol eder
--   2) DonationItems.RemainingQty'yi düşürür
--
-- Ne zaman tetiklenir?
--   SuspendedFoodClaims tablosuna yeni kayıt eklendiğinde.
--
-- Neden trigger?
--   İş kuralları (günlük limit, stok kontrolü) veritabanı
--   katmanında zorlanır. Uygulama bypass edilse bile kural çalışır.
-- =============================================
CREATE TRIGGER trg_BagisKalanGuncelle
ON SuspendedFoodClaims
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- KONTROL 1: Günlük talep limiti (max 2/gün)
    -- Bugün aynı yararlanıcının kaç talep yaptığını sayar.
    IF EXISTS (
        SELECT 1
        FROM SuspendedFoodClaims sc
            INNER JOIN inserted i ON sc.BeneficiaryID = i.BeneficiaryID
        WHERE CAST(sc.ClaimDate AS DATE) = CAST(i.ClaimDate AS DATE)
          AND sc.IsActive = 1
        GROUP BY sc.BeneficiaryID, CAST(sc.ClaimDate AS DATE)
        -- 2'den fazlaysa (yeni eklenenle birlikte 3 olmuşsa) → ENGELLE
        HAVING COUNT(*) > 2
    )
    BEGIN
        -- RAISERROR: Kullanıcıya anlamlı hata mesajı döner.
        -- Severity 16 = kullanıcı hatası, State 1 = genel durum.
        RAISERROR(N'Günlük talep limiti aşıldı! Bir kullanıcı günde en fazla 2 kez yararlanabilir.', 16, 1);
        -- ROLLBACK: Tüm işlemi geri alır, INSERT iptal edilir.
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- KONTROL 2: Havuzda yeterli yemek var mı?
    IF EXISTS (
        SELECT 1
        FROM DonationItems di
            INNER JOIN inserted i ON di.DonationItemID = i.DonationItemID
        WHERE di.RemainingQty < i.Quantity
    )
    BEGIN
        RAISERROR(N'Havuzda yeterli yemek kalmadı!', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- Her şey uygunsa → RemainingQty'yi düşür
    UPDATE DonationItems
    SET RemainingQty = RemainingQty - i.Quantity
    FROM DonationItems di
        INNER JOIN inserted i ON di.DonationItemID = i.DonationItemID;
END;
GO


-- =============================================================================
-- ==========================  INDEX'LER (Dizinler)  ===========================
-- =============================================================================

-- =============================================
-- INDEX AÇIKLAMASI:
-- Index, bir kitabın sonundaki dizin gibidir.
-- Tüm sayfaları taramak yerine (Table Scan) dizinden
-- bakarak doğrudan ilgili sayfaya gidersiniz (Index Seek).
-- 
-- Nereye index koyarız?
--   1) JOIN'lerde kullanılan FK sütunları
--   2) WHERE filtrelemelerinde sık kullanılan sütunlar
--   3) ORDER BY ile sıralanan sütunlar
-- 
-- Nereye index KOYMAYIZ?
--   1) Çok az satırı olan tablolara (3 restoran → index gereksiz)
--   2) Çok sık UPDATE/INSERT yapılan sütunlara (index güncelleme maliyeti)
--   3) PK sütunlarına (zaten otomatik index oluşturulur)
-- =============================================

-- Orders tablosu en çok sorgulanan tablo olacağı için
-- FK ve filtreleme sütunlarına index eklenir.

-- 1) Müşteriye göre sipariş arama: "Ayşe'nin tüm siparişleri"
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID 
ON Orders(CustomerID);

-- 2) Restorana göre sipariş arama: "Kibar Usta'nın tüm siparişleri"
CREATE NONCLUSTERED INDEX IX_Orders_RestaurantID 
ON Orders(RestaurantID);

-- 3) Duruma göre filtreleme: "Teslim edilmemiş siparişler"
--    INCLUDE: Status ile birlikte sık çekilen sütunlar index'e dahil edilir.
--    Böylece tablo yerine doğrudan index'ten okunur (covering index).
CREATE NONCLUSTERED INDEX IX_Orders_Status 
ON Orders(Status)
INCLUDE (CustomerID, RestaurantID, TotalAmount);

-- 4) Sipariş detaylarını çekme: "1 numaralı siparişin kalemleri"
CREATE NONCLUSTERED INDEX IX_OrderDetails_OrderID 
ON OrderDetails(OrderID);

-- 5) Menü kalemine göre arama: "Adana Kebap hangi siparişlerde var?"
CREATE NONCLUSTERED INDEX IX_OrderDetails_MenuItemID 
ON OrderDetails(MenuItemID);

-- 6) Bağış kalemlerini çekme: "1 numaralı bağışın kalemleri"
CREATE NONCLUSTERED INDEX IX_DonationItems_DonationID 
ON DonationItems(DonationID);

-- 7) Talep geçmişi: "Zeynep'in tüm talepleri"
CREATE NONCLUSTERED INDEX IX_Claims_BeneficiaryID 
ON SuspendedFoodClaims(BeneficiaryID);
GO

-- =============================================================================
-- MEVCUT VERİLER İÇİN CİRO GÜNCELLEME
-- Trigger yeni eklenen siparişlerde çalışır, ama mevcut
-- "Teslim Edildi" siparişleri için ciroyu elle güncellememiz gerekir.
-- =============================================================================
UPDATE Restaurants
SET TotalRevenue = ISNULL((
    SELECT SUM(o.TotalAmount) 
    FROM Orders o 
    WHERE o.RestaurantID = Restaurants.RestaurantID 
      AND o.Status = N'Teslim Edildi' 
      AND o.IsActive = 1
), 0);
GO

PRINT N'✅ Adım 4 tamamlandı!';
PRINT N'📊 2 View, 2 Trigger, 7 Index oluşturuldu.';
PRINT N'💰 Restoran ciroları güncellendi.';
GO
