# 🍽️ Birlikte Güzel — Çevrimiçi Yemek Sipariş Platformu

VTYS-1 Dönem Projesi | Veritabanı Tasarımı

## 📋 Proje Hakkında

**Birlikte Güzel**, restoran, müşteri ve kurye bileşenlerini içeren bir çevrimiçi yemek sipariş platformu veritabanı tasarımıdır. Platformun en önemli özelliği **"Askıda Yemek"** modülüdür: Hayırseverler belirli yemek kalemleri bağışlayabilir, doğrulanmış ihtiyaç sahipleri bu havuzdan günde en fazla 2 kez yararlanabilir.

## 🗂️ Veritabanı Yapısı (10 Tablo)

| Tablo | Açıklama |
|-------|----------|
| `Customers` | Müşteri bilgileri |
| `Restaurants` | Restoran bilgileri ve ciro takibi |
| `Couriers` | Kurye bilgileri (havuz sistemi) |
| `MenuItems` | Menü kalemleri ve fiyatları |
| `Orders` | Sipariş kayıtları |
| `OrderDetails` | Sipariş detayları (M:N çözüm tablosu) |
| `SuspendedFoodDonations` | Askıda yemek bağışları |
| `DonationItems` | Bağış kalemleri (M:N çözüm tablosu) |
| `Beneficiaries` | Doğrulanmış ihtiyaç sahipleri |
| `SuspendedFoodClaims` | Havuzdan alınan yemek talepleri |

## 🛠️ Teknik Özellikler

- **3NF uyumlu** veritabanı tasarımı
- **Soft Delete** (IsActive) yapısı — veri fiziksel olarak silinmez
- **CHECK, UNIQUE, NOT NULL** constraint'leri
- **Computed Column** (LineTotal = Quantity × UnitPrice)
- **2 View**: Sipariş detay raporu, Askıda yemek havuzu durumu
- **2 Trigger**: Ciro güncelleme, Bağış bakiye düşürme + günlük limit kontrolü
- **7 Index**: Performans optimizasyonu
- **4 Analitik Sorgu**: JOIN (6 tablo), GROUP BY/HAVING, Subquery (IN/EXISTS), NOT EXISTS

## 📂 Dosya Yapısı

```
├── BirlikteGuzel_Tum_Kodlar.sql   -- Tüm SQL kodları (DDL + DML + View + Trigger + Index + Sorgular)
└── README.md                       -- Bu dosya
```

## ⚙️ Kurulum

1. SQL Server Management Studio (SSMS) açın
2. `BirlikteGuzel_Tum_Kodlar.sql` dosyasını açın
3. F5 ile çalıştırın
