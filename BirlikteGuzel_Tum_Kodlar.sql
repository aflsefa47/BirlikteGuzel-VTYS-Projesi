-- =============================================
-- BİRLİKTE GÜZEL — Çevrimiçi Yemek Sipariş Platformu
-- VTYS-1 Dönem Projesi — TÜM KODLAR
-- =============================================
-- İçindekiler:
--   BÖLÜM 1: Veritabanı ve Tablo Oluşturma (DDL)
--   BÖLÜM 2: Örnek Veri Ekleme (DML)
--   BÖLÜM 3: Görünümler (Views)
--   BÖLÜM 4: Tetikleyiciler (Triggers)
--   BÖLÜM 5: Dizinler (Indexes)
--   BÖLÜM 6: Analitik Sorgular
-- =============================================


-- =============================================================================
-- ===  BÖLÜM 1: VERİTABANI ve TABLO OLUŞTURMA (DDL)  ========================
-- =============================================================================

CREATE DATABASE BirlikteGuzel;
GO
USE BirlikteGuzel;
GO

-- =============================================
-- TABLO 1: Customers (Müşteriler)
-- =============================================
CREATE TABLE Customers (
    CustomerID    INT           IDENTITY(1,1) PRIMARY KEY,
    FirstName     NVARCHAR(50)  NOT NULL,
    LastName      NVARCHAR(50)  NOT NULL,
    Email         NVARCHAR(100) NOT NULL UNIQUE,
    Phone         VARCHAR(15)   NOT NULL,
    Address       NVARCHAR(255) NOT NULL,
    RegistrationDate DATETIME   DEFAULT GETDATE(),
    IsActive      BIT           DEFAULT 1
);
GO

-- =============================================
-- TABLO 2: Restaurants (Restoranlar)
-- =============================================
CREATE TABLE Restaurants (
    RestaurantID  INT           IDENTITY(1,1) PRIMARY KEY,
    Name          NVARCHAR(100) NOT NULL,
    Address       NVARCHAR(255) NOT NULL,
    Phone         VARCHAR(15)   NOT NULL,
    OpeningTime   TIME,
    ClosingTime   TIME,
    Rating        DECIMAL(3,2)  DEFAULT 0 
                  CHECK (Rating >= 0 AND Rating <= 5),
    TotalRevenue  DECIMAL(12,2) DEFAULT 0,
    IsActive      BIT           DEFAULT 1
);
GO

-- =============================================
-- TABLO 3: Couriers (Kuryeler)
-- =============================================
CREATE TABLE Couriers (
    CourierID     INT           IDENTITY(1,1) PRIMARY KEY,
    FirstName     NVARCHAR(50)  NOT NULL,
    Phone         VARCHAR(15)   NOT NULL,
    VehicleType   NVARCHAR(30),
    IsAvailable   BIT           DEFAULT 1,
    IsActive      BIT           DEFAULT 1
);
GO

-- =============================================
-- TABLO 4: MenuItems (Menü Kalemleri)
-- =============================================
CREATE TABLE MenuItems (
    MenuItemID    INT           IDENTITY(1,1) PRIMARY KEY,
    RestaurantID  INT           NOT NULL,
    ItemName      NVARCHAR(100) NOT NULL,
    Description   NVARCHAR(255),
    Price         DECIMAL(10,2) NOT NULL 
                  CHECK (Price > 0),
    IsActive      BIT           DEFAULT 1,
    CONSTRAINT FK_MenuItems_Restaurants 
        FOREIGN KEY (RestaurantID) REFERENCES Restaurants(RestaurantID)
);
GO

-- =============================================
-- TABLO 5: Orders (Siparişler)
-- =============================================
CREATE TABLE Orders (
    OrderID       INT           IDENTITY(1,1) PRIMARY KEY,
    CustomerID    INT           NOT NULL,
    RestaurantID  INT           NOT NULL,
    CourierID     INT           NULL,
    OrderDate     DATETIME      DEFAULT GETDATE(),
    Status        NVARCHAR(20)  NOT NULL 
                  CHECK (Status IN (N'Hazırlanıyor', N'Yolda', N'Teslim Edildi', N'İptal')),
    PaymentMethod NVARCHAR(20)  NOT NULL 
                  CHECK (PaymentMethod IN (N'Nakit', N'Kredi Kartı', N'Online')),
    TotalAmount   DECIMAL(10,2) NOT NULL 
                  CHECK (TotalAmount >= 0),
    IsActive      BIT           DEFAULT 1,
    CONSTRAINT FK_Orders_Customers 
        FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    CONSTRAINT FK_Orders_Restaurants 
        FOREIGN KEY (RestaurantID) REFERENCES Restaurants(RestaurantID),
    CONSTRAINT FK_Orders_Couriers 
        FOREIGN KEY (CourierID) REFERENCES Couriers(CourierID)
);
GO

-- =============================================
-- TABLO 6: OrderDetails (Sipariş Detayları)
-- =============================================
CREATE TABLE OrderDetails (
    OrderDetailID INT           IDENTITY(1,1) PRIMARY KEY,
    OrderID       INT           NOT NULL,
    MenuItemID    INT           NOT NULL,
    Quantity      INT           NOT NULL 
                  CHECK (Quantity > 0),
    UnitPrice     DECIMAL(10,2) NOT NULL 
                  CHECK (UnitPrice > 0),
    LineTotal     AS (Quantity * UnitPrice),
    IsActive      BIT           DEFAULT 1,
    CONSTRAINT FK_OrderDetails_Orders 
        FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    CONSTRAINT FK_OrderDetails_MenuItems 
        FOREIGN KEY (MenuItemID) REFERENCES MenuItems(MenuItemID)
);
GO

-- =============================================
-- TABLO 7: SuspendedFoodDonations (Askıda Yemek Bağışları)
-- =============================================
CREATE TABLE SuspendedFoodDonations (
    DonationID      INT      IDENTITY(1,1) PRIMARY KEY,
    DonorCustomerID INT      NOT NULL,
    DonationDate    DATETIME DEFAULT GETDATE(),
    IsAnonymous     BIT      DEFAULT 1,
    IsActive        BIT      DEFAULT 1,
    CONSTRAINT FK_Donations_Customers 
        FOREIGN KEY (DonorCustomerID) REFERENCES Customers(CustomerID)
);
GO

-- =============================================
-- TABLO 8: DonationItems (Bağış Kalemleri)
-- =============================================
CREATE TABLE DonationItems (
    DonationItemID INT      IDENTITY(1,1) PRIMARY KEY,
    DonationID     INT      NOT NULL,
    MenuItemID     INT      NOT NULL,
    Quantity       INT      NOT NULL 
                   CHECK (Quantity > 0),
    RemainingQty   INT      NOT NULL 
                   CHECK (RemainingQty >= 0),
    IsActive       BIT      DEFAULT 1,
    CONSTRAINT FK_DonationItems_Donations 
        FOREIGN KEY (DonationID) REFERENCES SuspendedFoodDonations(DonationID),
    CONSTRAINT FK_DonationItems_MenuItems 
        FOREIGN KEY (MenuItemID) REFERENCES MenuItems(MenuItemID)
);
GO

-- =============================================
-- TABLO 9: Beneficiaries (İhtiyaç Sahipleri)
-- =============================================
CREATE TABLE Beneficiaries (
    BeneficiaryID    INT           IDENTITY(1,1) PRIMARY KEY,
    CustomerID       INT           NOT NULL UNIQUE,
    VerificationType NVARCHAR(30)  NOT NULL 
                     CHECK (VerificationType IN (N'GelirBeyanı', N'ÖğrenciBelgesi')),
    IsVerified       BIT           DEFAULT 0,
    VerificationDate DATETIME,
    IsActive         BIT           DEFAULT 1,
    CONSTRAINT FK_Beneficiaries_Customers 
        FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
GO

-- =============================================
-- TABLO 10: SuspendedFoodClaims (Askıda Yemek Talepleri)
-- =============================================
CREATE TABLE SuspendedFoodClaims (
    ClaimID        INT      IDENTITY(1,1) PRIMARY KEY,
    BeneficiaryID  INT      NOT NULL,
    DonationItemID INT      NOT NULL,
    Quantity       INT      NOT NULL 
                   CHECK (Quantity > 0),
    ClaimDate      DATETIME DEFAULT GETDATE(),
    IsActive       BIT      DEFAULT 1,
    CONSTRAINT FK_Claims_Beneficiaries 
        FOREIGN KEY (BeneficiaryID) REFERENCES Beneficiaries(BeneficiaryID),
    CONSTRAINT FK_Claims_DonationItems 
        FOREIGN KEY (DonationItemID) REFERENCES DonationItems(DonationItemID)
);
GO


-- =============================================================================
-- ===  BÖLÜM 2: ÖRNEK VERİ EKLEME (DML)  =====================================
-- =============================================================================

INSERT INTO Customers (FirstName, LastName, Email, Phone, Address) VALUES
(N'Ayşe',   N'Demir',  N'ayse.demir@email.com',   '05301234567', N'Atatürk Cad. No:12 Adana'),
(N'Mehmet', N'Kaya',   N'mehmet.kaya@email.com',   '05329876543', N'İnönü Mah. No:5 Adana'),
(N'Zeynep', N'Yılmaz', N'zeynep.yilmaz@email.com', '05551112233', N'Cumhuriyet Blv. No:8 Adana');
GO

INSERT INTO Restaurants (Name, Address, Phone, OpeningTime, ClosingTime, Rating) VALUES
(N'Kibar Usta',           N'Merkez Mah. No:1 Adana',  '03221112233', '09:00', '23:00', 4.50),
(N'Ciğerci Yusuf Usta',   N'Çarşı Cad. No:15 Adana',  '03224445566', '10:00', '22:00', 4.70),
(N'Aras Katık',           N'Bahçe Sok. No:3 Adana',    '03227778899', '07:00', '20:00', 4.30);
GO

INSERT INTO Couriers (FirstName, Phone, VehicleType) VALUES
(N'Veysel', '05401112233', N'Motosiklet'),
(N'Yusuf',  '05404445566', N'Motosiklet'),
(N'Furkan', '05407778899', N'Bisiklet');
GO

-- Kibar Usta menüsü
INSERT INTO MenuItems (RestaurantID, ItemName, Description, Price) VALUES
(1, N'Adana Kebap',  N'Acılı el yapımı kebap, közlenmiş biber ve domates ile', 250.00),
(1, N'Urfa Kebap',   N'Acısız özel harç kebap, lavaş ekmek ile',              240.00),
(1, N'Lahmacun',     N'İnce hamur, kıymalı, bol maydanoz ve limon ile',        120.00),
(1, N'Ayran',        N'Taze yayık ayranı',                                      30.00);

-- Ciğerci Yusuf Usta menüsü
INSERT INTO MenuItems (RestaurantID, ItemName, Description, Price) VALUES
(2, N'Ciğer Porsiyon', N'Adana usulü baharatlı ciğer, soğan ve maydanoz ile', 200.00),
(2, N'Ciğer Dürüm',    N'Lavaşa sarılmış ciğer, acı sos ile',                 150.00),
(2, N'Ciğer Şiş',      N'Şişe dizilmiş ciğer, közlenmiş biber ile',           180.00),
(2, N'Şalgam',          N'Acılı geleneksel şalgam suyu',                        25.00);

-- Aras Katık menüsü
INSERT INTO MenuItems (RestaurantID, ItemName, Description, Price) VALUES
(3, N'Serpme Kahvaltı', N'Zengin kahvaltı tabağı, peynir, zeytin, bal, kaymak', 350.00),
(3, N'Katık Tabağı',    N'Geleneksel ev yapımı katık çeşitleri',                 180.00),
(3, N'Gözleme',         N'El açması, peynirli veya kıymalı seçenekli',           100.00),
(3, N'Menemen',          N'Domates, biber ve yumurta ile geleneksel menemen',     120.00),
(3, N'Çay',              N'Demlik çay, ince belli bardakta',                      20.00);
GO

INSERT INTO Orders (CustomerID, RestaurantID, CourierID, OrderDate, Status, PaymentMethod, TotalAmount) VALUES
(1, 1, 1, '2025-05-15 12:30:00', N'Teslim Edildi', N'Nakit',       280.00),
(2, 2, 2, '2025-05-15 13:00:00', N'Teslim Edildi', N'Kredi Kartı', 350.00),
(3, 3, NULL, '2025-05-16 08:00:00', N'Hazırlanıyor', N'Online',    390.00),
(1, 2, 3, '2025-05-16 19:45:00', N'Yolda',         N'Online',      405.00),
(2, 3, 1, '2025-05-17 09:15:00', N'Teslim Edildi', N'Nakit',       320.00);
GO

INSERT INTO OrderDetails (OrderID, MenuItemID, Quantity, UnitPrice) VALUES
(1, 1, 1, 250.00), (1, 4, 1, 30.00),
(2, 6, 2, 150.00), (2, 8, 2, 25.00),
(3, 9, 1, 350.00), (3, 13, 2, 20.00),
(4, 5, 1, 200.00), (4, 7, 1, 180.00), (4, 8, 1, 25.00);

INSERT INTO OrderDetails (OrderID, MenuItemID, Quantity, UnitPrice) VALUES
(5, 11, 2, 100.00), (5, 12, 1, 120.00);
GO

INSERT INTO SuspendedFoodDonations (DonorCustomerID, DonationDate, IsAnonymous) VALUES
(1, '2025-05-16 10:00:00', 1),
(2, '2025-05-17 11:30:00', 0);
GO

INSERT INTO DonationItems (DonationID, MenuItemID, Quantity, RemainingQty) VALUES
(1, 3, 2, 2), (1, 4, 2, 2), (2, 6, 3, 3);
GO

INSERT INTO Beneficiaries (CustomerID, VerificationType, IsVerified, VerificationDate) VALUES
(3, N'ÖğrenciBelgesi', 1, '2025-05-14 09:00:00');
GO

INSERT INTO SuspendedFoodClaims (BeneficiaryID, DonationItemID, Quantity, ClaimDate) VALUES
(1, 1, 1, '2025-05-17 12:00:00'),
(1, 3, 1, '2025-05-17 13:00:00');
GO

UPDATE DonationItems SET RemainingQty = 1 WHERE DonationItemID = 1;
UPDATE DonationItems SET RemainingQty = 2 WHERE DonationItemID = 3;
GO


-- =============================================================================
-- ===  BÖLÜM 3: GÖRÜNÜMLER (Views)  ==========================================
-- =============================================================================

CREATE VIEW vw_SiparisDetayRaporu AS
SELECT
    o.OrderID                          AS SiparisNo,
    c.FirstName + ' ' + c.LastName     AS MusteriAdi,
    c.Phone                            AS MusteriTelefon,
    r.Name                             AS RestoranAdi,
    ISNULL(k.FirstName, N'Atanmadı')   AS KuryeAdi,
    o.OrderDate                        AS SiparisTarihi,
    o.Status                           AS Durum,
    o.PaymentMethod                    AS OdemeYontemi,
    o.TotalAmount                      AS ToplamTutar
FROM Orders o
    INNER JOIN Customers   c ON o.CustomerID   = c.CustomerID
    INNER JOIN Restaurants r ON o.RestaurantID = r.RestaurantID
    LEFT JOIN  Couriers    k ON o.CourierID    = k.CourierID
WHERE o.IsActive = 1;
GO

CREATE VIEW vw_AskidaYemekHavuzu AS
SELECT
    di.DonationItemID                AS KalemID,
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
  AND di.RemainingQty > 0;
GO


-- =============================================================================
-- ===  BÖLÜM 4: TETİKLEYİCİLER (Triggers)  ==================================
-- =============================================================================

CREATE TRIGGER trg_CiroGuncelle
ON Orders
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Restaurants
    SET TotalRevenue = TotalRevenue + i.TotalAmount
    FROM Restaurants r
        INNER JOIN inserted i ON r.RestaurantID = i.RestaurantID
    WHERE i.Status = N'Teslim Edildi'
      AND NOT EXISTS (
          SELECT 1 FROM deleted d 
          WHERE d.OrderID = i.OrderID 
            AND d.Status = N'Teslim Edildi'
      );

    UPDATE Restaurants
    SET TotalRevenue = TotalRevenue - d.TotalAmount
    FROM Restaurants r
        INNER JOIN deleted d ON r.RestaurantID = d.RestaurantID
        INNER JOIN inserted i ON d.OrderID = i.OrderID
    WHERE d.Status = N'Teslim Edildi'
      AND i.Status = N'İptal';
END;
GO

CREATE TRIGGER trg_BagisKalanGuncelle
ON SuspendedFoodClaims
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM SuspendedFoodClaims sc
            INNER JOIN inserted i ON sc.BeneficiaryID = i.BeneficiaryID
        WHERE CAST(sc.ClaimDate AS DATE) = CAST(i.ClaimDate AS DATE)
          AND sc.IsActive = 1
        GROUP BY sc.BeneficiaryID, CAST(sc.ClaimDate AS DATE)
        HAVING COUNT(*) > 2
    )
    BEGIN
        RAISERROR(N'Günlük talep limiti aşıldı! Bir kullanıcı günde en fazla 2 kez yararlanabilir.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

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

    UPDATE DonationItems
    SET RemainingQty = RemainingQty - i.Quantity
    FROM DonationItems di
        INNER JOIN inserted i ON di.DonationItemID = i.DonationItemID;
END;
GO


-- =============================================================================
-- ===  BÖLÜM 5: DİZİNLER (Indexes)  ==========================================
-- =============================================================================

CREATE NONCLUSTERED INDEX IX_Orders_CustomerID 
ON Orders(CustomerID);

CREATE NONCLUSTERED INDEX IX_Orders_RestaurantID 
ON Orders(RestaurantID);

CREATE NONCLUSTERED INDEX IX_Orders_Status 
ON Orders(Status)
INCLUDE (CustomerID, RestaurantID, TotalAmount);

CREATE NONCLUSTERED INDEX IX_OrderDetails_OrderID 
ON OrderDetails(OrderID);

CREATE NONCLUSTERED INDEX IX_OrderDetails_MenuItemID 
ON OrderDetails(MenuItemID);

CREATE NONCLUSTERED INDEX IX_DonationItems_DonationID 
ON DonationItems(DonationID);

CREATE NONCLUSTERED INDEX IX_Claims_BeneficiaryID 
ON SuspendedFoodClaims(BeneficiaryID);
GO

-- Mevcut veriler için ciro güncelleme
UPDATE Restaurants
SET TotalRevenue = ISNULL((
    SELECT SUM(o.TotalAmount) 
    FROM Orders o 
    WHERE o.RestaurantID = Restaurants.RestaurantID 
      AND o.Status = N'Teslim Edildi' 
      AND o.IsActive = 1
), 0);
GO


-- =============================================================================
-- ===  BÖLÜM 6: ANALİTİK SORGULAR  ==========================================
-- =============================================================================

-- SORGU 1: JOIN — Detaylı Sipariş Fişi Raporu (6 Tablo)
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
    FORMAT(o.OrderDate, 'dd.MM.yyyy HH:mm')  AS [Tarih]
FROM Orders o
    INNER JOIN Customers    c  ON o.CustomerID    = c.CustomerID
    INNER JOIN Restaurants  r  ON o.RestaurantID  = r.RestaurantID
    LEFT JOIN  Couriers     k  ON o.CourierID     = k.CourierID
    INNER JOIN OrderDetails od ON o.OrderID       = od.OrderID
    INNER JOIN MenuItems    m  ON od.MenuItemID   = m.MenuItemID
WHERE o.IsActive = 1
ORDER BY o.OrderDate, o.OrderID, od.OrderDetailID;
GO

-- SORGU 2: GROUP BY + HAVING — Restoran Performans Analizi
SELECT 
    r.Name                                      AS [Restoran],
    COUNT(o.OrderID)                             AS [Toplam Sipariş],
    CAST(SUM(o.TotalAmount) AS DECIMAL(10,2))    AS [Toplam Ciro (₺)],
    CAST(AVG(o.TotalAmount) AS DECIMAL(10,2))    AS [Ort. Sipariş (₺)],
    CAST(MAX(o.TotalAmount) AS DECIMAL(10,2))    AS [En Yüksek Sipariş (₺)],
    FORMAT(MIN(o.OrderDate), 'dd.MM.yyyy')       AS [İlk Sipariş],
    FORMAT(MAX(o.OrderDate), 'dd.MM.yyyy')       AS [Son Sipariş]
FROM Restaurants r
    LEFT JOIN Orders o ON r.RestaurantID = o.RestaurantID
                      AND o.Status = N'Teslim Edildi'
                      AND o.IsActive = 1
WHERE r.IsActive = 1
GROUP BY r.Name
HAVING SUM(o.TotalAmount) > 300
ORDER BY [Toplam Ciro (₺)] DESC;
GO

-- SORGU 3: SUBQUERY (IN) — Bağış Yapan Müşterilerin Sipariş Analizi
SELECT 
    c.FirstName + ' ' + c.LastName     AS [Müşteri],
    COUNT(o.OrderID)                    AS [Sipariş Sayısı],
    ISNULL(SUM(o.TotalAmount), 0)       AS [Toplam Harcama (₺)],
    (SELECT COUNT(*) 
     FROM SuspendedFoodDonations d 
     WHERE d.DonorCustomerID = c.CustomerID 
       AND d.IsActive = 1)              AS [Bağış Sayısı]
FROM Customers c
    LEFT JOIN Orders o ON c.CustomerID = o.CustomerID 
                       AND o.IsActive = 1
WHERE c.CustomerID IN (
    SELECT DonorCustomerID 
    FROM SuspendedFoodDonations 
    WHERE IsActive = 1
)
GROUP BY c.CustomerID, c.FirstName, c.LastName
ORDER BY [Toplam Harcama (₺)] DESC;
GO

-- SORGU 3B: SUBQUERY (EXISTS) — Aynı sonuç, farklı yaklaşım
SELECT 
    c.FirstName + ' ' + c.LastName      AS [Müşteri],
    c.Email                              AS [E-posta],
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
WHERE EXISTS (
    SELECT 1 
    FROM SuspendedFoodDonations d 
    WHERE d.DonorCustomerID = c.CustomerID 
      AND d.IsActive = 1
);
GO

-- BONUS: NOT EXISTS — Hiç Sipariş Verilmemiş Menü Kalemleri
SELECT 
    r.Name       AS [Restoran],
    m.ItemName   AS [Yemek],
    m.Price      AS [Fiyat (₺)]
FROM MenuItems m
    INNER JOIN Restaurants r ON m.RestaurantID = r.RestaurantID
WHERE m.IsActive = 1
  AND NOT EXISTS (
      SELECT 1 
      FROM OrderDetails od 
      WHERE od.MenuItemID = m.MenuItemID 
        AND od.IsActive = 1
  )
ORDER BY r.Name, m.ItemName;
GO

PRINT N'✅ BirlikteGuzel veritabanı tüm bileşenleriyle başarıyla oluşturuldu!';
GO
