# ربط إشعارات Firebase (FCM) — Bolman Web Dashboard

**مشروع Firebase:** `safarbus`  
**Project ID:** `safarbus-2b9b0`

---

## 1) عدّل ملف `.env`

**المسار:** `E:\bolman_web_dashboard\.env`

استبدل محتوى الملف بالكامل بهذا:

```env
VITE_SUPABASE_URL=https://uvwzdbpisgxvasfkchbu.supabase.co
VITE_SUPABASE_ANON_KEY=sb_publishable_CwdlJmaAudGKhp-6ZcATBg_absL391D

VITE_FIREBASE_API_KEY=AIzaSyBRiMjraiaL2UUohfTjswkPj3C3td9lsn4
VITE_FIREBASE_AUTH_DOMAIN=safarbus-2b9b0.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=safarbus-2b9b0
VITE_FIREBASE_STORAGE_BUCKET=safarbus-2b9b0.firebasestorage.app
VITE_FIREBASE_MESSAGING_SENDER_ID=771850549676
VITE_FIREBASE_APP_ID=1:771850549676:web:f58b8f04cb9a48f8c62209
VITE_FIREBASE_VAPID_KEY=BNX3uz2jZUuOyl56ZmWe98zdhcc04VX1ARcActrNBlMPdC7a11N8c_qWY2GNNqn5hkWPpvc7Xi2PW2yareAAKdA
```

بعد الحفظ:

```bash
npm run dev
```

أعد تشغيل السيرفر — لا تكفي إعادة تحميل الصفحة.

---

## 2) ضع ملف Service Account

**الملف:** `safarbus-2b9b0-firebase-adminsdk-fbsvc-6705772e62.json`

- لا تضعه في `src/` أو `public/`
- لا ترفعه على GitHub
- أضفه كـ Secret في Supabase:
  - **الاسم:** `FIREBASE_SERVICE_ACCOUNT_JSON`
  - **القيمة:** محتوى ملف JSON كاملًا

---

## 3) أكمل الكود

### أ) Frontend — تسجيل توكن FCM

**الملف:** `src/lib/firebase.ts` (جاهز — لا تعدّله)

**المطلوب:** استدعِ `registerWebFcmToken()` بعد تسجيل الدخول.

```ts
import { registerWebFcmToken } from '../lib/firebase';

// بعد نجاح تسجيل الدخول
const permission = await Notification.requestPermission();
if (permission === 'granted') {
  await navigator.serviceWorker.register('/firebase-messaging-sw.js');
  await registerWebFcmToken();
}
```

**المكان:** بعد دخول المستخدم للوحة التحكم (مرة واحدة لكل جلسة).

---

### ب) Backend — إرسال Push

**الملف:** `supabase/functions/send-trip-notification/index.ts`

بعد إدراج صفوف `notifications`:

1. اجلب توكنات المستلمين من `user_fcm_tokens` حيث `is_active = true`
2. أرسل عبر **FCM HTTP v1** باستخدام `FIREBASE_SERVICE_ACCOUNT_JSON`
3. عطّل التوكنات غير الصالحة في الجدول

---

## 4) الملفات

```text
E:\bolman_web_dashboard\
├── .env                                    ← عدّله (الخطوة 1)
├── public/firebase-messaging-sw.js         ← Service Worker
├── src/lib/firebase.ts                     ← تهيئة Firebase
├── src/services/notification.service.ts
└── supabase/functions/send-trip-notification/index.ts  ← أضف إرسال FCM
```

---

## 5) تحقق

- [ ] `.env` محدّث بالقيم أعلاه
- [ ] `npm run dev` أُعيد تشغيله
- [ ] `registerWebFcmToken()` يُستدعى بعد الدخول
- [ ] المتصفح يطلب إذن الإشعارات ويُقبل
- [ ] Secret `FIREBASE_SERVICE_ACCOUNT_JSON` مضاف في Supabase
- [ ] Edge Function ترسل Push بعد حفظ إشعار الرحلة
- [ ] `.env` وملف JSON غير موجودين في `git status`

---

## 6) ممنوع

- وضع Service Account في Frontend
- استخدام Legacy Server Key
- رفع `.env` أو ملف JSON على GitHub
- الاعتماد على جدول `notifications` فقط بدون إرسال FCM
