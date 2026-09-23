# تعديل البروفايل + صورة البروفايل + نسيت كلمة المرور

هذا الملف يشرح ما تم إضافته للتطبيق، والخطوات المطلوبة منك في Supabase قبل أن تعمل الميزات.

---

## 1) الخطوات المطلوبة منك (إلزامية)

### 1.1 تشغيل ملف SQL

افتح **Supabase Dashboard → SQL Editor** وشغّل الملف:

```
bolman_cursor_reference_pack/bolman_profile_avatar_and_password.sql
```

الملف يقوم بثلاثة أمور:

| # | ما يفعله | لماذا |
|---|---------|-------|
| 1 | `alter table public.users add column avatar_url text` | مكان تخزين رابط صورة البروفايل |
| 2 | ينشئ bucket تخزين اسمه `avatars` + 4 سياسات RLS | مكان رفع الصور، وكل مستخدم يقرأ/يكتب في مجلده فقط |
| 3 | trigger يمنع المستخدم من تعديل `role` و `status` لنفسه | سدّ ثغرة أمنية، اقرأ القسم 4 |

> سياسة القراءة مقيّدة بمجلد المستخدم عن قصد. عرض الصور لا يحتاجها (الـ bucket عام والقراءة تمرّ عبر `/object/public/` وتتجاوز RLS)، ولو فتحناها للجميع لاستطاع أي شخص يملك anon key سرد معرّفات (UUID) كل مستخدمي النظام.

**ملاحظة ترتيب النشر:** ملف `AuthRepo` أصبح يقرأ عمود `avatar_url` عند تحميل البروفايل، أي أن نشر التطبيق **قبل** تشغيل هذا الملف يعطّل **تسجيل الدخول نفسه** لا الصور فقط. شغّل SQL أولًا. (تظهر رسالة واضحة تخبرك باسم الملف إن حدث ذلك.)

للتأكد من نجاح التشغيل، شغّل:

```sql
select column_name from information_schema.columns
 where table_schema='public' and table_name='users' and column_name='avatar_url';

select id, public, file_size_limit from storage.buckets where id='avatars';

select policyname from pg_policies
 where schemaname='storage' and tablename='objects' and policyname like 'avatars%';
```

يجب أن ترى: عمود `avatar_url`، و bucket `avatars` بـ `public = true`، و 4 سياسات.

---

### 1.2 إضافة رمز التحقق إلى قالب البريد (مهم لميزة نسيت كلمة المرور)

> **ملاحظة صريحة:** قلت لك سابقًا إن طريقة OTP لا تحتاج أي إعداد في لوحة تحكم Supabase. هذا كان غير دقيق — تحتاج تعديل سطر واحد في قالب البريد. لا تزال أبسط بكثير من طريقة Deep Link (التي تحتاج تعديل AndroidManifest و Info.plist و Redirect URLs)، لكن الخطوة موجودة ويجب أن تعرفها.

اذهب إلى **Authentication → Emails → Reset Password**.

**Subject:**
```
رمز إعادة تعيين كلمة المرور — بولمان
```

**Body** (تبويب Source):

```html
<div dir="rtl" style="font-family:-apple-system,'Segoe UI',Tahoma,Arial,sans-serif;background:#F8FAFC;padding:32px 16px;">
  <div style="max-width:520px;margin:0 auto;background:#FFFFFF;border-radius:16px;overflow:hidden;border:1px solid #E2E8F0;">

    <div style="background:#6C63FF;padding:24px;text-align:center;">
      <h1 style="margin:0;color:#FFFFFF;font-size:22px;font-weight:800;">بولمان</h1>
      <p style="margin:6px 0 0;color:#ECEBFF;font-size:13px;">النقل بين المحافظات</p>
    </div>

    <div style="padding:28px 24px;">
      <h2 style="margin:0 0 8px;color:#0F172A;font-size:19px;font-weight:800;">إعادة تعيين كلمة المرور</h2>
      <p style="margin:0 0 20px;color:#64748B;font-size:14px;line-height:1.7;">
        وصلنا طلب لإعادة تعيين كلمة مرور حسابك. أدخل الرمز التالي في التطبيق:
      </p>

      <div style="background:#ECEBFF;border:1px solid #B8B0FF;border-radius:12px;padding:20px 12px;text-align:center;margin-bottom:20px;">
        <div dir="ltr" style="font-family:'Courier New',monospace;font-size:26px;font-weight:700;letter-spacing:4px;color:#5146E5;white-space:nowrap;">{{ .Token }}</div>
      </div>

      <p style="margin:0 0 6px;color:#64748B;font-size:13px;line-height:1.7;">
        الرمز صالح لمدة ساعة واحدة ويُستخدم مرة واحدة فقط.
      </p>
      <p style="margin:0;color:#64748B;font-size:13px;line-height:1.7;">
        إن لم تطلب إعادة التعيين، تجاهل هذه الرسالة ولن يتغير شيء في حسابك.
      </p>
    </div>

    <div style="background:#F1F5F9;padding:16px 24px;text-align:center;border-top:1px solid #E2E8F0;">
      <p style="margin:0;color:#94A3B8;font-size:12px;">لا ترسل هذا الرمز لأي شخص، ولن يطلبه منك فريق بولمان أبدًا.</p>
    </div>

  </div>
</div>
```

**لا تضع `{{ .ConfirmationURL }}` في القالب.** رمز الاستعادة يُستخدم مرة واحدة، والرابط يحتوي نفس الرمز — فلو ضغط المستخدم على الرابط استُهلك الرمز ولم يعد إدخال الأرقام في التطبيق يعمل.

**طول الرمز:** مشروعك يُصدر رموزًا من 8 أرقام (Supabase يسمح بـ 6–10، ويمكن تغييره من Authentication → Sign In / Providers → Email). الكود في التطبيق يقبل أي طول بين 6 و10، فلا حاجة لتعديل شيء. القيم `font-size:26px` و `letter-spacing:4px` و `white-space:nowrap` أعلاه مضبوطة كي لا ينكسر رمز الـ 8 أرقام على سطرين.

**إذا لم تُنفّذ هذه الخطوة، الميزة تبقى تعمل:** الكود يقبل أيضًا لصق الرابط كاملًا من البريد ويستخرج الرمز منه بنفسه (انظر `AuthRepo.confirmPasswordReset`). لكن تجربة المستخدم بالرمز المكوّن من 6 أرقام أفضل بكثير.

---

### 1.3 تفعيل Developer Mode على ويندوز (للتطوير فقط)

عند تشغيل `flutter pub get` ظهرت رسالة:

```
Building with plugins requires symlink support.
Please enable Developer Mode in your system settings.
```

هذه مشكلة موجودة أصلًا في بيئتك وليست من التعديلات. لحلّها:

```
start ms-settings:developers
```

وفعّل **Developer Mode**. هذا مطلوب لبناء إضافات Flutter على ويندوز.

---

## 2) ما تم إضافته في التطبيق

### 2.1 تعديل البروفايل

**المسار:** `/profile/edit` — الوصول من شاشة البروفايل (زر التعديل أو الضغط على الصورة).

| الحقل | قابل للتعديل | ملاحظة |
|------|-------------|--------|
| صورة البروفايل | ✅ | كاميرا / معرض / حذف |
| الاسم الكامل | ✅ | حرفان على الأقل |
| رقم الهاتف | ✅ | فريد في قاعدة البيانات، يظهر خطأ واضح إن كان مستخدمًا |
| البريد الإلكتروني | ❌ | معطّل — بريد الدخول يملكه Supabase Auth وتغييره يحتاج تدفّق تأكيد منفصل |
| الدور / الحالة | ❌ | لا يظهران أصلًا، ويرفضهما الـ trigger على مستوى قاعدة البيانات |

زر الحفظ يبقى معطّلًا حتى يتغير شيء فعلًا.

### 2.2 صورة البروفايل

- تُصغَّر الصورة إلى 720×720 بجودة 85% **قبل** الرفع، فلا تصل أبدًا إلى حد 2MB.
- مسار الرفع: `avatars/<user_id>/<timestamp>.jpg`
- الطابع الزمني في الاسم يضمن أن CDN لا يعرض الصورة القديمة بعد التغيير.
- بعد كل رفع ناجح، تُحذف الصور القديمة في مجلد المستخدم تلقائيًا (best-effort — فشل الحذف لا يُفشل الحفظ).
- تظهر الصورة في: شاشة البروفايل، شاشة التعديل، وشريط الصفحة الرئيسية.
- عند عدم وجود صورة يظهر أول حرف من الاسم بدل أيقونة عامة.

### 2.3 نسيت كلمة المرور

**المسار:** `/forgot` — من رابط "نسيت كلمة المرور؟" في شاشة الدخول.

التدفّق كله داخل التطبيق، بخطوتين على نفس الشاشة:

1. إدخال البريد → إرسال رمز التحقق.
2. إدخال الرمز + كلمة المرور الجديدة + تأكيدها → تعيين كلمة المرور.

بعد النجاح يُسجَّل المستخدم دخولًا مباشرة ويُنقل إلى واجهته (راكب أو سائق) دون طلب دخول جديد.

يقبل حقل الرمز:
- الرمز المكوّن من 6 أرقام (يحتاج الخطوة 1.2).
- الرابط كاملًا ملصوقًا من البريد (يعمل مع القالب الافتراضي).
- الرمز الطويل (hash) وحده.

يوجد زر **إعادة إرسال الرمز**.

### 2.4 تغيير كلمة المرور (للمستخدم المسجَّل)

**المسار:** `/change-password` — من شاشة البروفايل أو شاشة تعديل البروفايل.

يطلب كلمة المرور الحالية ويتحقق منها **على السيرفر** قبل قبول الجديدة، حتى لا يستطيع أحد يحمل هاتفًا مفتوحًا تغيير كلمة المرور.

---

## 3) الملفات المتأثرة

**جديدة:**

| الملف | الدور |
|------|------|
| `lib/features/shared/edit_profile_screen.dart` | شاشة تعديل البروفايل |
| `lib/features/shared/change_password_screen.dart` | شاشة تغيير كلمة المرور |
| `lib/features/shared/user_avatar.dart` | ويدجت الصورة المشترك |
| `bolman_cursor_reference_pack/bolman_profile_avatar_and_password.sql` | تعديلات الباك-إند |

**معدّلة:**

| الملف | التعديل |
|------|--------|
| `lib/data/models.dart` | `Profile`: إضافة `avatarUrl` و `copyWith` و `initial` ومساواة بالقيمة |
| `lib/data/repositories.dart` | `AuthRepo`: `updateProfile` / `uploadAvatar` / `removeAvatar` / `changePassword` / `sendPasswordResetCode` / `confirmPasswordReset` |
| `lib/features/cubits.dart` | `ProfileEditCubit` / `ChangePasswordCubit` / `PasswordResetCubit` + `AuthCubit.applyProfile` |
| `lib/features/auth/auth_screens.dart` | إعادة كتابة `ForgotScreen` بخطوتين |
| `lib/features/shared/profile_screen.dart` | بطاقة بروفايل بالصورة + مدخلات التعديل وكلمة المرور |
| `lib/features/passenger/home_screen.dart` | صورة البروفايل في شريط العنوان |
| `lib/app/router.dart` | مسارات `/profile/edit` و `/change-password` |
| `lib/app/i18n/locales/{ar,en}.dart` | مفاتيح الترجمة الجديدة |
| `lib/features/shared/formatters.dart` | رسائل أخطاء واضحة للحالات الجديدة |
| `pubspec.yaml` | `image_picker` + `cached_network_image` |
| `ios/Runner/Info.plist` | `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` |

---

## 4) ملاحظة أمنية مهمة

أثناء دراسة الكود وجدت ثغرة **موجودة قبل هذه الميزة**:

سياسة `users_update_own_policy` في `bolman_schema.sql` تسمح بـ:

```sql
USING (id = auth.uid()) WITH CHECK (id = auth.uid())
```

أي أنها تسمح بتعديل **كل الأعمدة** في صف المستخدم، بما فيها `role`. يعني أي راكب يستطيع تنفيذ:

```sql
update public.users set role = 'super_admin' where id = auth.uid();
```

ويصبح مدير نظام.

الملف `bolman_profile_avatar_and_password.sql` يسدّ هذه الثغرة عبر trigger اسمه `prevent_self_privilege_change`، وهو:

- **لا يؤثر** على Edge Functions التي تستخدم service_role (لأن `auth.uid()` تكون `null` هناك).
- **لا يؤثر** على تعديل الشركة لبيانات سائقيها (لأن `id` يختلف عن `auth.uid()`).
- يرفض فقط أن يعدّل المستخدم دوره أو حالة حسابه بنفسه.

إن أردت التحقّق قبل الاعتماد عليه، اختبر من الداشبورد: تعديل بيانات سائق، وتعطيل/تفعيل مستخدم. كلاهما يجب أن يعمل كما كان.

---

## 5) اختبار القبول

### تعديل البروفايل
1. سجّل دخولًا بحساب راكب.
2. البروفايل → تعديل البروفايل.
3. غيّر الاسم → احفظ → يجب أن يتغير الاسم في شاشة البروفايل **وفي ترحيب الصفحة الرئيسية**.
4. غيّر رقم الهاتف إلى رقم موجود لحساب آخر → يجب أن تظهر رسالة "رقم الهاتف مستخدم من حساب آخر".

### صورة البروفايل
1. تعديل البروفايل → اضغط أيقونة الكاميرا.
2. "اختيار من المعرض" → اختر صورة → تظهر فورًا مع رسالة نجاح.
3. أغلق التطبيق وأعد فتحه → الصورة لا تزال موجودة.
4. من نفس القائمة → "حذف الصورة" → يعود أول حرف من الاسم.
5. في Supabase → Storage → avatars → يجب أن ترى مجلدًا واحدًا بمعرّف المستخدم يحتوي ملفًا واحدًا فقط (لا تتراكم الصور).

### نسيت كلمة المرور
1. اخرج من الحساب → شاشة الدخول → "نسيت كلمة المرور؟".
2. أدخل بريد حساب موجود → إرسال.
3. افتح البريد وخذ الرمز (أو انسخ الرابط كاملًا).
4. أدخل الرمز + كلمة مرور جديدة + التأكيد → تعيين.
5. يجب أن تدخل مباشرة إلى الصفحة الرئيسية.
6. اخرج ثم سجّل دخولًا بكلمة المرور الجديدة → يجب أن ينجح.
7. جرّب رمزًا خاطئًا → رسالة "رمز التحقق غير صحيح أو منتهي الصلاحية".
8. **حالة حرجة:** أدخل رمزًا صحيحًا ثم اقطع الإنترنت قبل الضغط على "تعيين". يجب أن يفشل بخطأ، ثم أعد فتح التطبيق → يجب أن تجد نفسك **خارج الحساب**، لا داخله. (رمز التحقق يفتح جلسة حقيقية، فالكود يُسجّل الخروج عند فشل تعيين كلمة المرور حتى لا تدخل بكلمة المرور القديمة.)

### تغيير كلمة المرور
1. البروفايل → تغيير كلمة المرور.
2. أدخل كلمة مرور حالية **خاطئة** → رسالة "بيانات الدخول غير صحيحة"، ويجب أن تبقى مسجّل الدخول.
3. أدخل الكلمة الصحيحة + كلمة جديدة + تأكيدها → نجاح.
4. اخرج وسجّل دخولًا بالكلمة الجديدة.

### السائق
كل ما سبق يجب أن يعمل من `/driver/profile` أيضًا (الشاشتان مشتركتان بين الراكب والسائق).
