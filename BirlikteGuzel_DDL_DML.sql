-- =============================================
-- BİRLİKTE GÜZEL — Çevrimiçi Yemek Sipariş Platformu
-- VTYS-1 Dönem Projesi
-- Adım 3: DDL + DML İşlemleri
-- =============================================

-- =============================================
-- VERİTABANI OLUŞTURMA
-- =============================================
CREATE DATABASE BirlikteGuzel;
GO
USE BirlikteGuzel;
GO

-- =============================================
-- TABLO 1: Customers (Müşteriler)
-- Amaç: Platformdaki tüm müşteri bilgilerini tutar.
--        Bir müşteri hem sipariş veren, hem bağışçı,
--        hem de ihtiyaç sahibi rolünde olabilir.
-- =============================================
CREATE TABLE Customers (
    -- IDENTITY(1,1): Otomatik artan PK. JOIN performansı için INT tercih edildi.
    CustomerID    INT           IDENTITY(1,1) PRIMARY KEY,

    -- NVARCHAR: Türkçe karakter desteği (ç, ş, ğ, ü, ö, ı) için Unicode şart.
    -- VARCHAR kullanılsaydı "Ayşe" → "Ayse" gibi veri kaybı olurdu.
    FirstName     NVARCHAR(50)  NOT NULL,
    LastName      NVARCHAR(50)  NOT NULL,

    -- UNIQUE: Aynı e-posta ile iki hesap açılamaz → iş kuralı.
    -- NOT NULL: Kayıt için e-posta zorunlu.
    Email         NVARCHAR(100) NOT NULL UNIQUE,

    -- VARCHAR(15): Telefon numaraları yalnızca rakam ve '+' içerir,
    -- Unicode desteğine gerek yok. 15 karakter uluslararası format için yeterli (+90XXXXXXXXXX).
    Phone         VARCHAR(15)   NOT NULL,

    Address       NVARCHAR(255) NOT NULL,

    -- DEFAULT GETDATE(): Kayıt anında otomatik tarih atanır, uygulama katmanına bağımlılık azalır.
    RegistrationDate DATETIME   DEFAULT GETDATE(),

    -- SOFT DELETE: Veri fiziksel olarak silinmez, IsActive=0 yapılarak pasife çekilir.
    -- Avantajları: Veri kaybı önlenir, yasal gereklilikler karşılanır, geri alma mümkün olur.
    IsActive      BIT           DEFAULT 1
);
GO

-- =============================================
-- TABLO 2: Restaurants (Restoranlar)
-- Amaç: Platform üzerindeki restoranların bilgilerini
--        ve toplam ciro takibini sağlar.
-- =============================================
CREATE TABLE Restaurants (
    RestaurantID  INT           IDENTITY(1,1) PRIMARY KEY,
    Name          NVARCHAR(100) NOT NULL,
    Address       NVARCHAR(255) NOT NULL,
    Phone         VARCHAR(15)   NOT NULL,

    -- TIME veri tipi: Sadece saat bilgisi yeterli, tarih gereksiz.
    -- DATETIME kullanmak 8 byte harcar, TIME sadece 5 byte.
    OpeningTime   TIME,
    ClosingTime   TIME,

    -- DECIMAL(3,2): 0.00–5.00 arası puan. Tam 2 ondalık hassasiyet.
    -- FLOAT kullanılsaydı 4.70 → 4.6999999... gibi yuvarlama hatası oluşurdu.
    -- CHECK: İş kuralı → puan 0'dan küçük veya 5'ten büyük olamaz.
    Rating        DECIMAL(3,2)  DEFAULT 0 
                  CHECK (Rating >= 0 AND Rating <= 5),

    -- DECIMAL(12,2): Ciro büyük rakamlara ulaşabilir (milyonlar).
    -- 10 hane tamsayı + 2 ondalık = yeterli kapasite.
    -- Bu alan trigger ile otomatik güncellenir (denormalizasyon → performans).
    TotalRevenue  DECIMAL(12,2) DEFAULT 0,

    IsActive      BIT           DEFAULT 1
);
GO

-- =============================================
-- TABLO 3: Couriers (Kuryeler)
-- Amaç: Havuz sistemindeki kurye bilgilerini tutar.
--        Herhangi bir kurye, herhangi bir restoranın
--        siparişini teslim edebilir.
-- =============================================
CREATE TABLE Couriers (
    CourierID     INT           IDENTITY(1,1) PRIMARY KEY,

    -- Kullanıcı talebi: Kuryeler için soyisim gerekli değil.
    FirstName     NVARCHAR(50)  NOT NULL,
    Phone         VARCHAR(15)   NOT NULL,

    -- NULL olabilir: Her kuryenin araç tipi henüz belirlenmemiş olabilir.
    VehicleType   NVARCHAR(30),

    -- IsAvailable: Kuryenin o an müsait olup olmadığını gösterir.
    -- IsActive'den farklıdır: IsAvailable=0 → meşgul, IsActive=0 → sistemden çıkarılmış.
    IsAvailable   BIT           DEFAULT 1,
    IsActive      BIT           DEFAULT 1
);
GO

-- =============================================
-- TABLO 4: MenuItems (Menü Kalemleri)
-- Amaç: Her restoranın sunduğu yemekleri ve fiyatlarını tutar.
-- İlişki: Restaurants 1:N MenuItems
-- =============================================
CREATE TABLE MenuItems (
    MenuItemID    INT           IDENTITY(1,1) PRIMARY KEY,

    -- FK: Her menü kalemi mutlaka bir restorana ait olmalı.
    -- NOT NULL: Restoransız menü kalemi olamaz.
    RestaurantID  INT           NOT NULL,

    ItemName      NVARCHAR(100) NOT NULL,
    Description   NVARCHAR(255),

    -- DECIMAL(10,2): Para hesaplamalarında kesin hassasiyet.
    -- CHECK (Price > 0): Negatif veya sıfır fiyatlı ürün mantıksız.
    Price         DECIMAL(10,2) NOT NULL 
                  CHECK (Price > 0),

    IsActive      BIT           DEFAULT 1,

    -- FOREIGN KEY: Referans bütünlüğü → RestaurantID'nin Restaurants tablosunda var olmasını garanti eder.
    CONSTRAINT FK_MenuItems_Restaurants 
        FOREIGN KEY (RestaurantID) REFERENCES Restaurants(RestaurantID)
);
GO

-- =============================================
-- TABLO 5: Orders (Siparişler)
-- Amaç: Müşterilerin restoranlardan verdiği siparişlerin
--        ana kaydını tutar.
-- İlişkiler: Customers 1:N Orders
--            Restaurants 1:N Orders
--            Couriers 1:N Orders
-- =============================================
CREATE TABLE Orders (
    OrderID       INT           IDENTITY(1,1) PRIMARY KEY,
    CustomerID    INT           NOT NULL,
    RestaurantID  INT           NOT NULL,

    -- NULL olabilir: Sipariş verildiğinde henüz kurye atanmamış olabilir.
    -- Sipariş "Hazırlanıyor" aşamasında kurye belli değildir.
    CourierID     INT           NULL,

    OrderDate     DATETIME      DEFAULT GETDATE(),

    -- CHECK IN: Sadece tanımlı durumlar kabul edilir.
    -- N prefix: NVARCHAR literal → Türkçe karakterlerin doğru saklanması için.
    Status        NVARCHAR(20)  NOT NULL 
                  CHECK (Status IN (N'Hazırlanıyor', N'Yolda', N'Teslim Edildi', N'İptal')),

    PaymentMethod NVARCHAR(20)  NOT NULL 
                  CHECK (PaymentMethod IN (N'Nakit', N'Kredi Kartı', N'Online')),

    -- CHECK >= 0: İptal edilmiş siparişin tutarı 0 olabilir ama negatif olamaz.
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
-- Amaç: Bir siparişin içindeki ürün kalemlerini tutar.
--        Orders ↔ MenuItems arasındaki M:N ilişkiyi çözer.
-- İlişkiler: Orders 1:N OrderDetails
--            MenuItems 1:N OrderDetails
-- =============================================
CREATE TABLE OrderDetails (
    OrderDetailID INT           IDENTITY(1,1) PRIMARY KEY,
    OrderID       INT           NOT NULL,
    MenuItemID    INT           NOT NULL,

    Quantity      INT           NOT NULL 
                  CHECK (Quantity > 0),

    -- UnitPrice: Sipariş anındaki fiyat burada sabitlenir.
    -- Menüdeki fiyat değişse bile eski siparişler etkilenmez.
    -- Bu, fiyat geçmişinin korunması için kritik bir tasarım kararıdır.
    UnitPrice     DECIMAL(10,2) NOT NULL 
                  CHECK (UnitPrice > 0),

    -- COMPUTED COLUMN (Hesaplanmış Sütun): Fiziksel olarak saklanmaz,
    -- sorgu anında otomatik hesaplanır. Veri tutarsızlığı riskini ortadan kaldırır.
    -- Quantity veya UnitPrice değişirse LineTotal otomatik güncellenir.
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
-- Amaç: Hayırseverlerin yaptığı bağış kayıtlarını tutar.
-- İlişki: Customers 1:N SuspendedFoodDonations
-- =============================================
CREATE TABLE SuspendedFoodDonations (
    DonationID      INT      IDENTITY(1,1) PRIMARY KEY,

    -- Bağışçı müşteri. NOT NULL: Anonim olsa bile sistem bağışçıyı bilmeli.
    DonorCustomerID INT      NOT NULL,

    DonationDate    DATETIME DEFAULT GETDATE(),

    -- IsAnonymous: Bağışçının kimlik tercihini saklar.
    -- DEFAULT 1 → varsayılan olarak anonim (gizlilik öncelikli tasarım).
    -- 0 = İsmim görünsün, 1 = İsmim gizlensin.
    IsAnonymous     BIT      DEFAULT 1,

    IsActive        BIT      DEFAULT 1,

    CONSTRAINT FK_Donations_Customers 
        FOREIGN KEY (DonorCustomerID) REFERENCES Customers(CustomerID)
);
GO

-- =============================================
-- TABLO 8: DonationItems (Bağış Kalemleri)
-- Amaç: Bir bağışın içindeki yemek kalemlerini tutar.
--        SuspendedFoodDonations ↔ MenuItems M:N ilişkisini çözer.
-- İlişkiler: SuspendedFoodDonations 1:N DonationItems
--            MenuItems 1:N DonationItems
-- =============================================
CREATE TABLE DonationItems (
    DonationItemID INT      IDENTITY(1,1) PRIMARY KEY,
    DonationID     INT      NOT NULL,
    MenuItemID     INT      NOT NULL,

    -- Quantity: Bağışlanan toplam miktar (örn: 3 adet Lahmacun).
    Quantity       INT      NOT NULL 
                   CHECK (Quantity > 0),

    -- RemainingQty: Havuzda kalan miktar.
    -- Trigger ile otomatik güncellenir (talep edildikçe azalır).
    -- CHECK >= 0: Negatif kalan miktar olamaz.
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
-- Amaç: Askıda yemek havuzundan yararlanabilecek
--        doğrulanmış kullanıcıları tutar.
-- İlişki: Customers 1:1 Beneficiaries (UNIQUE ile sağlanır)
-- =============================================
CREATE TABLE Beneficiaries (
    BeneficiaryID    INT           IDENTITY(1,1) PRIMARY KEY,

    -- UNIQUE: Bir müşteri en fazla bir kez ihtiyaç sahibi kaydı oluşturabilir.
    -- Bu 1:1 ilişkiyi garanti eder ve mükerrer kayıtları engeller.
    CustomerID       INT           NOT NULL UNIQUE,

    -- CHECK IN: Sadece tanımlı doğrulama türleri kabul edilir.
    -- GelirBeyanı → Aylık gelir beyanı belgesi
    -- ÖğrenciBelgesi → Öğrenci belgesi + kimlik doğrulaması
    VerificationType NVARCHAR(30)  NOT NULL 
                     CHECK (VerificationType IN (N'GelirBeyanı', N'ÖğrenciBelgesi')),

    -- DEFAULT 0: Başvuru yapılır ama admin onayı bekler.
    IsVerified       BIT           DEFAULT 0,

    -- NULL olabilir: Henüz doğrulanmamışsa tarih yok.
    VerificationDate DATETIME,

    IsActive         BIT           DEFAULT 1,

    CONSTRAINT FK_Beneficiaries_Customers 
        FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
GO

-- =============================================
-- TABLO 10: SuspendedFoodClaims (Askıda Yemek Talepleri)
-- Amaç: İhtiyaç sahiplerinin havuzdan aldığı yemekleri kaydeder.
-- İlişkiler: Beneficiaries 1:N SuspendedFoodClaims
--            DonationItems 1:N SuspendedFoodClaims
-- İş Kuralı: Günde en fazla 2 talep (uygulama katmanında kontrol).
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
-- =====================  DML İŞLEMLERİ (Örnek Veriler)  =======================
-- =============================================================================

-- =============================================
-- MÜŞTERİLER (3 Kayıt)
-- =============================================
INSERT INTO Customers (FirstName, LastName, Email, Phone, Address) VALUES
(N'Ayşe',   N'Demir',  N'ayse.demir@email.com',   '05301234567', N'Atatürk Cad. No:12 Adana'),
(N'Mehmet', N'Kaya',   N'mehmet.kaya@email.com',   '05329876543', N'İnönü Mah. No:5 Adana'),
(N'Zeynep', N'Yılmaz', N'zeynep.yilmaz@email.com', '05551112233', N'Cumhuriyet Blv. No:8 Adana');
GO

-- =============================================
-- RESTORANLAR (3 Kayıt)
-- =============================================
INSERT INTO Restaurants (Name, Address, Phone, OpeningTime, ClosingTime, Rating) VALUES
(N'Kibar Usta',           N'Merkez Mah. No:1 Adana',  '03221112233', '09:00', '23:00', 4.50),
(N'Ciğerci Yusuf Usta',   N'Çarşı Cad. No:15 Adana',  '03224445566', '10:00', '22:00', 4.70),
(N'Aras Katık',           N'Bahçe Sok. No:3 Adana',    '03227778899', '07:00', '20:00', 4.30);
GO

-- =============================================
-- KURYELER (3 Kayıt — Havuz Sistemi)
-- =============================================
INSERT INTO Couriers (FirstName, Phone, VehicleType) VALUES
(N'Veysel', '05401112233', N'Motosiklet'),
(N'Yusuf',  '05404445566', N'Motosiklet'),
(N'Furkan', '05407778899', N'Bisiklet');
GO

-- =============================================
-- MENÜ KALEMLERİ (13 Kayıt)
-- =============================================

-- Kibar Usta (RestaurantID = 1) — 4 ürün
INSERT INTO MenuItems (RestaurantID, ItemName, Description, Price) VALUES
(1, N'Adana Kebap',  N'Acılı el yapımı kebap, közlenmiş biber ve domates ile', 250.00),
(1, N'Urfa Kebap',   N'Acısız özel harç kebap, lavaş ekmek ile',              240.00),
(1, N'Lahmacun',     N'İnce hamur, kıymalı, bol maydanoz ve limon ile',        120.00),
(1, N'Ayran',        N'Taze yayık ayranı',                                      30.00);

-- Ciğerci Yusuf Usta (RestaurantID = 2) — 4 ürün
INSERT INTO MenuItems (RestaurantID, ItemName, Description, Price) VALUES
(2, N'Ciğer Porsiyon', N'Adana usulü baharatlı ciğer, soğan ve maydanoz ile', 200.00),
(2, N'Ciğer Dürüm',    N'Lavaşa sarılmış ciğer, acı sos ile',                 150.00),
(2, N'Ciğer Şiş',      N'Şişe dizilmiş ciğer, közlenmiş biber ile',           180.00),
(2, N'Şalgam',          N'Acılı geleneksel şalgam suyu',                        25.00);

-- Aras Katık (RestaurantID = 3) — 5 ürün
INSERT INTO MenuItems (RestaurantID, ItemName, Description, Price) VALUES
(3, N'Serpme Kahvaltı', N'Zengin kahvaltı tabağı, peynir, zeytin, bal, kaymak', 350.00),
(3, N'Katık Tabağı',    N'Geleneksel ev yapımı katık çeşitleri',                 180.00),
(3, N'Gözleme',         N'El açması, peynirli veya kıymalı seçenekli',           100.00),
(3, N'Menemen',          N'Domates, biber ve yumurta ile geleneksel menemen',     120.00),
(3, N'Çay',              N'Demlik çay, ince belli bardakta',                      20.00);
GO

-- =============================================
-- SİPARİŞLER (5 Kayıt)
-- =============================================
INSERT INTO Orders (CustomerID, RestaurantID, CourierID, OrderDate, Status, PaymentMethod, TotalAmount) VALUES
-- Sipariş 1: Ayşe → Kibar Usta (1 Adana Kebap + 1 Ayran = 280 TL)
(1, 1, 1, '2025-05-15 12:30:00', N'Teslim Edildi', N'Nakit',       280.00),

-- Sipariş 2: Mehmet → Ciğerci Yusuf Usta (2 Ciğer Dürüm + 2 Şalgam = 350 TL)
(2, 2, 2, '2025-05-15 13:00:00', N'Teslim Edildi', N'Kredi Kartı', 350.00),

-- Sipariş 3: Zeynep → Aras Katık (1 Serpme Kahvaltı + 2 Çay = 390 TL)
(3, 3, NULL, '2025-05-16 08:00:00', N'Hazırlanıyor', N'Online',    390.00),

-- Sipariş 4: Ayşe → Ciğerci Yusuf Usta (1 Ciğer Porsiyon + 1 Ciğer Şiş + 1 Şalgam = 405 TL)
(1, 2, 3, '2025-05-16 19:45:00', N'Yolda',         N'Online',      405.00),

-- Sipariş 5: Mehmet → Aras Katık (2 Gözleme + 1 Menemen = 320 TL)
(2, 3, 1, '2025-05-17 09:15:00', N'Teslim Edildi', N'Nakit',       320.00);
GO

-- =============================================
-- SİPARİŞ DETAYLARI (9 Kayıt)
-- =============================================
INSERT INTO OrderDetails (OrderID, MenuItemID, Quantity, UnitPrice) VALUES
-- Sipariş 1 detayları (Ayşe - Kibar Usta)
(1, 1, 1, 250.00),   -- 1x Adana Kebap
(1, 4, 1,  30.00),   -- 1x Ayran

-- Sipariş 2 detayları (Mehmet - Ciğerci Yusuf Usta)
(2, 6, 2, 150.00),   -- 2x Ciğer Dürüm
(2, 8, 2,  25.00),   -- 2x Şalgam

-- Sipariş 3 detayları (Zeynep - Aras Katık)
(3, 9,  1, 350.00),  -- 1x Serpme Kahvaltı
(3, 13, 2,  20.00),  -- 2x Çay

-- Sipariş 4 detayları (Ayşe - Ciğerci Yusuf Usta)
(4, 5, 1, 200.00),   -- 1x Ciğer Porsiyon
(4, 7, 1, 180.00),   -- 1x Ciğer Şiş
(4, 8, 1,  25.00);   -- 1x Şalgam

-- Sipariş 5 detayları (Mehmet - Aras Katık)
INSERT INTO OrderDetails (OrderID, MenuItemID, Quantity, UnitPrice) VALUES
(5, 11, 2, 100.00),  -- 2x Gözleme
(5, 12, 1, 120.00);  -- 1x Menemen
GO

-- =============================================
-- ASKIDA YEMEK BAĞIŞLARI (2 Kayıt)
-- =============================================
INSERT INTO SuspendedFoodDonations (DonorCustomerID, DonationDate, IsAnonymous) VALUES
-- Bağış 1: Ayşe → Kibar Usta'dan 2 Lahmacun + 2 Ayran bağışlıyor (anonim)
(1, '2025-05-16 10:00:00', 1),

-- Bağış 2: Mehmet → Ciğerci Yusuf Usta'dan 3 Ciğer Dürüm bağışlıyor (ismi görünsün)
(2, '2025-05-17 11:30:00', 0);
GO

-- =============================================
-- BAĞIŞ KALEMLERİ (3 Kayıt)
-- RemainingQty başlangıçta Quantity'ye eşittir.
-- Talep edildikçe trigger ile düşecektir.
-- =============================================
INSERT INTO DonationItems (DonationID, MenuItemID, Quantity, RemainingQty) VALUES
-- Bağış 1 kalemleri (Ayşe'nin bağışı)
(1, 3, 2, 2),   -- 2x Lahmacun (MenuItemID=3, Kibar Usta)
(1, 4, 2, 2),   -- 2x Ayran    (MenuItemID=4, Kibar Usta)

-- Bağış 2 kalemleri (Mehmet'in bağışı)
(2, 6, 3, 3);   -- 3x Ciğer Dürüm (MenuItemID=6, Ciğerci Yusuf Usta)
GO

-- =============================================
-- İHTİYAÇ SAHİPLERİ (1 Kayıt)
-- Zeynep öğrenci belgesi ile doğrulanmış
-- =============================================
INSERT INTO Beneficiaries (CustomerID, VerificationType, IsVerified, VerificationDate) VALUES
(3, N'ÖğrenciBelgesi', 1, '2025-05-14 09:00:00');
GO

-- =============================================
-- ASKIDA YEMEK TALEPLERİ (2 Kayıt)
-- Zeynep havuzdan yemek talep ediyor
-- İş Kuralı: Günde en fazla 2 talep
-- =============================================
INSERT INTO SuspendedFoodClaims (BeneficiaryID, DonationItemID, Quantity, ClaimDate) VALUES
-- Talep 1: Zeynep, Ayşe'nin bağışından 1 Lahmacun alıyor
(1, 1, 1, '2025-05-17 12:00:00'),

-- Talep 2: Zeynep, Mehmet'in bağışından 1 Ciğer Dürüm alıyor
(1, 3, 1, '2025-05-17 13:00:00');
GO

-- =============================================
-- NOT: RemainingQty güncellemesi Adım 4'te
-- oluşturulacak Trigger ile otomatik yapılacak.
-- Şu an elle güncelleyelim ki veri tutarlı olsun.
-- =============================================
UPDATE DonationItems SET RemainingQty = 1 WHERE DonationItemID = 1;  -- 2-1=1 Lahmacun kaldı
UPDATE DonationItems SET RemainingQty = 2 WHERE DonationItemID = 3;  -- 3-1=2 Ciğer Dürüm kaldı
GO

PRINT N'✅ BirlikteGuzel veritabanı başarıyla oluşturuldu!';
PRINT N'📊 10 tablo, 13 menü kalemi, 5 sipariş, 2 bağış, 2 talep eklendi.';
GO
