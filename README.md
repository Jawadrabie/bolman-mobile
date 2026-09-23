# Bolman Mobile 🚌

تطبيق موبايل متكامل لحجز رحلات الباصات بين المدن، مبني بـ **Flutter**، ويخدم فئتين من المستخدمين ضمن تطبيق واحد: **الراكب** و **السائق**. يعتمد على **Supabase** (Postgres + Auth + RPC + Storage) كخلفية للبيانات، و **Firebase Cloud Messaging** للإشعارات الفورية.

[![Flutter](https://img.shields.io/badge/Flutter-3.4%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.4%2B-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Firebase](https://img.shields.io/badge/Push-Firebase%20FCM-FFCA28?logo=firebase&logoColor=white)](https://firebase.google.com)

---

## نظرة عامة | Overview

**Bolman** is a two-sided Flutter app for intercity bus travel: passengers search trips, pick seats, pay, and manage bookings with QR tickets, while drivers manage their assigned trips and scan tickets at boarding. State management uses `flutter_bloc`/Cubit, navigation uses `go_router`, and all data access goes through Supabase RPC functions with Row Level Security.

## المحتويات | Contents

- [الميزات](#الميزات--features)
- [التقنيات المستخدمة](#التقنيات-المستخدمة--tech-stack)
- [هيكل المشروع](#هيكل-المشروع--project-structure)
- [البدء السريع](#البدء-السريع--getting-started)
- [إعداد Supabase و Firebase](#إعداد-supabase-و-firebase)
- [التشغيل](#التشغيل--running-the-app)
- [الاختبارات](#الاختبارات--tests)
- [ملاحظات أمنية](#ملاحظات-أمنية--security-notes)

## الميزات | Features

### 🧑‍💼 الراكب (Passenger)
- البحث عن رحلات بين المدن حسب التاريخ والمصدر والوجهة.
- اختيار المقاعد بشكل تفاعلي (Seat grid) وحجزها في نفس اللحظة (Seat locking).
- الدفع عبر المحفظة الرقمية (Wallet) وإتمام الحجز.
- عرض التذاكر برمز QR قابل للمسح عند الصعود، ومشاركتها.
- إدارة الحجوزات: تعديل، إلغاء، أو إكمال دفع حجز معلّق (Pay pending booking).
- فلترة الحجوزات حسب الفترة (قادمة / سابقة).
- الملف الشخصي: تعديل البيانات، تغيير كلمة المرور، رفع صورة شخصية.
- دعم لغتين (عربي / إنجليزي) وتصميم متجاوب مع الوضع الليلي.
- إشعارات فورية (Push notifications) لحالة الحجز والرحلة.

### 🚍 السائق (Driver)
- عرض الرحلات المخصصة للسائق (مرتبطة بحسابه عبر `auth.uid()`).
- مسح تذاكر الركاب (QR) عند الصعود بشكل موثوق وسريع.
- تفاصيل الرحلة والركاب المسجلين فيها.

## التقنيات المستخدمة | Tech Stack

| الطبقة | التقنية |
|---|---|
| Framework | Flutter (Dart >= 3.4) |
| إدارة الحالة | `flutter_bloc` / Cubit + `equatable` |
| التنقل | `go_router` |
| الخلفية / قاعدة البيانات | Supabase (Postgres, Auth, RPC, Storage) |
| الإشعارات | Firebase Core + Firebase Messaging + `flutter_local_notifications` |
| QR | `qr_flutter` (توليد) / `mobile_scanner` (مسح) |
| تخزين محلي | `shared_preferences` |
| الوسائط والصور | `cached_network_image`, `image_picker`, `flutter_svg`, `lottie` |
| التدويل | `flutter_localizations`, `intl` |

## هيكل المشروع | Project Structure

```
lib/
├── main.dart                     # نقطة الدخول
├── app/
│   ├── app.dart                  # MaterialApp + إعدادات عامة
│   ├── router.dart               # مسارات go_router
│   ├── theme.dart                # الألوان والتصميم (Purple + Mint)
│   ├── settings_cubit.dart       # إعدادات اللغة / الثيم
│   ├── splash_screen.dart
│   └── i18n/                     # ملفات الترجمة (ar / en)
├── core/
│   ├── config.dart                # قراءة متغيرات البيئة (--dart-define)
│   ├── fcm_service.dart           # إعداد Firebase Messaging
│   ├── firebase_options.dart
│   ├── datetime_utils.dart
│   └── driver_trip_utils.dart
├── data/
│   ├── models.dart                # نماذج البيانات
│   └── repositories.dart          # طبقة الوصول لـ Supabase RPC
├── features/
│   ├── auth/                      # تسجيل الدخول / إنشاء حساب
│   ├── passenger/                 # الرئيسية، البحث، الحجز، المحفظة
│   ├── driver/                    # شاشات السائق ومسح التذاكر
│   ├── shared/                    # مكونات مشتركة (البروفايل، التذكرة، المقاعد...)
│   └── cubits.dart                # Cubits المشتركة بين الميزات
└── shared/                        # ودجات وحركات عامة (Shimmer, Animations...)
```

بقية المجلدات (`android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/`) هي مشاريع المنصّات القياسية التي يولّدها Flutter.

## البدء السريع | Getting Started

### المتطلبات
- [Flutter SDK](https://docs.flutter.dev/get-started/install) بإصدار 3.4 أو أحدث.
- حساب [Supabase](https://supabase.com) (URL + Anon Key) لمشروعك الخاص.
- حساب [Firebase](https://firebase.google.com) لتفعيل الإشعارات (اختياري لكن موصى به).

### التثبيت

```bash
git clone https://github.com/Jawadrabie/bolman-mobile.git
cd bolman-mobile
flutter pub get
```

## إعداد Supabase و Firebase

المشروع لا يتضمن مفاتيح أو ملفات اعتماد حقيقية داخل المستودع (تم استثناؤها عمداً). قبل التشغيل:

1. **Supabase**: مرّر رابط ومفتاح مشروعك عبر `--dart-define` عند التشغيل (انظر أدناه)، بدل تعديل الكود مباشرة. القراءة تتم في [`lib/core/config.dart`](lib/core/config.dart).
2. **Firebase**:
   - Android: ضع ملف `google-services.json` الخاص بمشروعك داخل `android/app/`.
   - iOS: ضع ملف `GoogleService-Info.plist` داخل `ios/Runner/`.
   - هذان الملفان مُدرجان في `.gitignore` لأنهما خاصان بكل مشروع/بيئة.

## التشغيل | Running the app

```bash
flutter analyze

flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

> على ويندوز (PowerShell)، استبدل `\` بـ backtick `` ` `` في نهاية كل سطر، أو ضعها في سطر واحد.

## الاختبارات | Tests

```bash
flutter test
```

## ملاحظات أمنية | Security Notes

- لا يحتوي المستودع على أي مفاتيح خدمة (Service Role Keys) أو ملفات اعتماد حقيقية.
- مفاتيح Supabase "Anon/Publishable" آمنة للكشف من جهة العميل بحكم تصميمها، وصلاحياتها الفعلية تُضبط عبر Row Level Security على الخادم — لكن يفضّل استخدام مشروع Supabase/Firebase خاص بك عند التطوير أو النشر.
- ملفات إعداد Firebase (`google-services.json` / `GoogleService-Info.plist`) مستبعدة من المستودع، أضِفها محلياً من إعدادات مشروعك.
- ملف `bolman_seed_full.sql` (تفريغ قاعدة بيانات كامل) ومجلد `bolman_cursor_reference_pack/` مستبعدان من الرفع العام لأنهما بيانات/مرجع داخلي وليسا كوداً مصدرياً للتطبيق.

---

<div align="center">Made with Flutter 💜</div>
