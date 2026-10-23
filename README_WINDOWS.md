# تشغيل منصة القليسي محلياً على Windows

هذا المستودع يحتوي على عدة أجزاء منفصلة: تطبيق العميل Flutter في الجذر، وتطبيق البائع Flutter داخل `seller_app/`، وخادم FastAPI داخل `backend/`، ولوحة الإدارة داخل `admin_dashboard/`، بالإضافة إلى نموذج Android أصلي مستقل بـ Jetpack Compose داخل `app/`. بناء أحد التطبيقات لا يعني أن بقية الخدمات أو OAuth منشورة على الإنترنت.

## المتطلبات

- Python 3.12 (مع خيار Add Python to PATH).
- Flutter stable 3.44.4 مع Android Studio وAndroid SDK.
- Git واتصال بالإنترنت لتنزيل المكتبات أول مرة.

## أول تشغيل للخادم

انقر مرتين على `run_backend.bat` أو شغّله من Terminal. سيقوم بإنشاء بيئة Python محلية `.venv/`، وتثبيت مكتبات `backend/requirements.txt` فيها، وإنشاء `.env` محلي عند الحاجة مع JWT secret عشوائي جديد، ثم تشغيل الخادم.

في التطوير، يترك الإعداد `DATABASE_URL` فارغاً عمداً كي يستخدم قاعدة SQLite المحلية `backend/alqulaisi.db`. ملف `.env` مستثنى من Git ولا ترفعه إلى المستودع. هذا الإعداد مخصص للتطوير فقط ولا يُستخدم للنشر الإنتاجي.

للتحقق من جاهزية الخادم افتح:
- فحص الصحة: `http://127.0.0.1:8000/health`
- توثيق API للتطوير: `http://127.0.0.1:8000/docs`

## تشغيل تطبيق العميل من Android Studio

افتح **مجلد المستودع الذي يحتوي على `pubspec.yaml`** بوصفه مشروع Flutter، وليس مجلد `app/` إن كان هدفك تطبيق العميل. من Terminal في جذر المستودع نفّذ:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

استخدام `10.0.2.2` مخصص لمحاكي Android للوصول إلى خادم التطوير الذي يعمل على حاسوب Windows. عند تشغيل تطبيق Windows Desktop، يستخدم العنوان `http://localhost:8000/api` افتراضياً.

إذا كنت تختبر على **هاتف Android حقيقي**، فإن `10.0.2.2` ليس عنوان الحاسوب على الشبكة. شغّل الخادم على واجهة الشبكة المحلية مثل `--host 0.0.0.0`، ثم مرّر عنوان IPv4 لحاسوبك في الشبكة نفسها، مثلاً `--dart-define=API_BASE_URL=http://192.168.1.20:8000/api` مع استبدال المثال بعنوان جهازك الحقيقي. اسمح للمنفذ 8000 في جدار الحماية لشبكة التطوير الخاصة فقط؛ لا تستخدم HTTP أو هذا الخادم المكشوف للإنتاج.

## تطبيق البائع

```powershell
cd seller_app
flutter pub get
flutter analyze
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

تسجيل الدخول برقم الهاتف وكلمة المرور يتصل بالخادم المحلي. تسجيل Google يحتاج معرّف Web OAuth حقيقياً يُمرر عند البناء بـ `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`، كما يحتاج `GOOGLE_CLIENT_ID` في إعداد الخادم وإعداد OAuth/SHA-1 المناسبين. لا تضع أسراراً أو ملفات مفاتيح في Git.

## تشغيل النظام على Windows دفعة واحدة

شغّل `run_all.bat`. سيطلق الخادم وينتظر حتى ينجح فحص `/health` قبل بدء تطبيق Flutter Desktop، بدلاً من بدء التطبيق بعد مهلة قصيرة ثابتة قد لا تكفي لتثبيت المكتبات.

## بناء نسخة APK للاختبار

من جذر المستودع:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

الملف المتوقع:
`build/app/outputs/flutter-apk/app-debug.apk`

تطبيق البائع:
`cd seller_app` ثم `flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000/api`

النموذج الأصلي Jetpack Compose (مجلد `app/`) مشروع Android منفصل؛ بناءه لا يبني تطبيق Flutter الخاص بالعميل.

## إنشاء حساب مدير للتجربة المحلية

لا ينشئ الخادم حساب مدير افتراضياً، ولا توجد كلمة مرور إدارية عامة داخل المستودع. بعد تشغيل الخادم مرة واحدة، افتح PowerShell في جذر المشروع وشغّل الأمر التالي باستخدام البيئة المحلية:

```powershell
.\.venv\Scripts\python.exe -m backend.create_admin --name "مدير منصة القليسي" --phone "9677XXXXXXXX" --email "admin@example.com"
```

استبدل رقم الهاتف والبريد بقيمك الحقيقية. سيطلب السكربت كلمة مرور بطول 14 حرفاً على الأقل ويخفيها أثناء الإدخال. لا تضع كلمة المرور في الأمر أو في Git. استخدم هذا الحساب للوحة الإدارة، وليس لتسجيل الدخول كتطبيق عميل.

## معرّفات تطبيق Android

المعرّفات الحالية مختلفة حسب التطبيق:
- تطبيق العميل Flutter: `com.example.alqulaisi_platform` داخل `android/app/build.gradle.kts`؛ ما زال معرّفاً افتراضياً ويجب اعتماد معرّف نهائي قبل إعداد Google OAuth أو نشر Release.
- تطبيق البائع Flutter: `com.alqlaisi.seller`.
- نموذج Jetpack Compose المستقل في `app/`: `com.alqlaisi.platform`، وهو ليس تطبيق العميل Flutter.

هذا الاختلاف لا يمنع بناء Debug، لكنه مهم عند إنشاء OAuth clients وبصمات SHA-1. لا تُنشئ إعداد OAuth لتطبيق العميل على أساس معرّف نموذج Compose.

## النشر الفعلي

قبل الإنتاج، يلزم عنوان API عام عبر HTTPS، وقاعدة PostgreSQL مع TLS، وJWT secret قوي، وقيم CORS والمضيفين والـ proxies الصحيحة، وإعداد Google OAuth وتوقيع Release. نجاح الاختبارات وبناء Debug لا يثبت أن OAuth الحقيقي أو الاستضافة الإنتاجية جاهزان.
