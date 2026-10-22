# منصة القليسي — دليل التشغيل والأمان

تتكون المنصة من تطبيق عميل Flutter في جذر المستودع، وتطبيق بائع مستقل داخل `seller_app/`، ولوحة إدارة ويب داخل `admin_dashboard/`، وخادم FastAPI في `backend/`.

## التشغيل المحلي على Windows

من PowerShell في جذر المستودع:

```powershell
py -3.12 -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r backend/requirements.txt
Copy-Item .env.example .env
python -m uvicorn backend.app.main:app --reload --host 127.0.0.1 --port 8000
```

اترك `DATABASE_URL` فارغاً للتطوير المحلي كي يستخدم الخادم SQLite. عدّل `JWT_SECRET_KEY` إلى قيمة عشوائية خاصة بك. توثيق API المحلي متاح على `http://127.0.0.1:8000/docs`، وهو معطّل في الإنتاج.

### تشغيل تطبيق العميل

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

العنوان `10.0.2.2` مخصص لمحاكي Android. عند تشغيل عميل Windows desktop استخدم `API_BASE_URL=http://127.0.0.1:8000/api`.

### تشغيل تطبيق البائع

```powershell
cd seller_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

يُقدّم المستخدم طلب متجر، ثم ينتظر اعتماد الإدارة. بعد الاعتماد يمكن للبائع إضافة المنتجات وإرسالها للمراجعة والتحكم بالتوافر والطلبات.

### تشغيل لوحة الإدارة

ارجع إلى جذر المستودع ثم شغّل:

```powershell
python -m http.server 5500
```

افتح `http://localhost:5500/admin_dashboard/` وسجّل الدخول بحساب مدير مُنشأ على الخادم. لا توجد آلية تسجيل إداري عامة داخل لوحة الويب.

## إعداد Google بصورة موثوقة

معرّف تطبيق العميل Android هو `com.alqlaisi.platform` ومعرّف تطبيق البائع `com.alqlaisi.seller`. أنشئ Android OAuth client لكل تطبيق باستخدام معرّف الحزمة الدقيق وبصمة SHA-1 لشهادة التوقيع.

أنشئ أيضاً OAuth client من نوع Web، ثم استخدم **معرّف Web نفسه** في الموضعين:

- في بناء تطبيق العميل: `--dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID`
- على الخادم: `GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID`

يتحقق الخادم من توقيع رمز Google والجمهور والصلاحية وكون البريد موثقاً. الحساب القديم الذي يُستخدم معه رقم الهاتف وكلمة المرور يجب أن يسجّل الدخول أولاً ثم يربط Google من صفحة الملف الشخصي؛ لا يتم دمج الحسابات اعتماداً على تطابق البريد وحده.

لا تستخدم معرفاً وهمياً. يلزم تسجيل SHA-1 الخاص بمفتاح Debug للاختبار المحلي وSHA-1 الخاص بمفتاح Release للإصدار النهائي. لا يمكن تأكيد تسجيل Google الحقيقي قبل إنشاء OAuth clients الفعلية وتجربة تسجيل الدخول على جهاز حقيقي.

## أمان إصدار Android والاستضافة

أصبحت معرّفات التطبيقات صريحة، وأزيل توقيع Release بمفتاح Debug. بناء Release يتطلب keystore خاصاً ومتغيرات بيئة للتوقيع. لا ترفع مفاتيح التوقيع أو كلمات المرور إلى Git.

راجع `backend/deployment/PRODUCTION_CHECKLIST.md` لإعداد PostgreSQL مع TLS، وسر JWT إنتاجي، وCORS وALLOWED_HOSTS محددين، وHTTPS، وNginx، وترحيل قاعدة البيانات. وجود Docker وملف Nginx لا يعني أن الاستضافة نُشرت فعلياً؛ يلزم حساب استضافة ونطاق وشهادات وأسرار صحيحة.

## نطاق الإصدار الأول

الدفع عند الاستلام، تقسيم السلة إلى طلب لكل متجر، حساب السعر ورسوم التوصيل على الخادم، اعتماد الإدارة لنشر المنتجات، وتحديد التوافر يدوياً بلا كميات مخزون. الإشعارات الفورية والدفع الإلكتروني والتحويلات المالية ونظام العمولات واستعادة كلمة المرور وتحليلات الذكاء الاصطناعي ليست مكتملة حتى تُهيأ خدماتها وتُختبر عملياً.

راجع `backend/ISSUE_REGISTER.md` لمعرفة بوابات الإطلاق المتبقية.
