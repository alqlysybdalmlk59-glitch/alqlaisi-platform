# تطبيق البائع — Alqlaisi

تطبيق Flutter مستقل لإدارة المتاجر والمنتجات والطلبات، ويتصل بخادم FastAPI المركزي، ويتضمن مشروع Android مستقلاً بمعرّف `com.alqlaisi.seller`.

## التشغيل

من جذر المستودع:
```bash
cd seller_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```
- العنوان `10.0.2.2` مخصص لمحاكي Android للوصول إلى الخادم على حاسوب التطوير. لهاتف حقيقي، استخدم عنوان IP المحلي للحاسوب.
- شغل الخادم من جذر المستودع: `uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload`.
- سجّل الدخول بحساب عميل، ثم قدّم طلب متجر. بعد موافقة الإدارة، سجّل الدخول مجدداً لفتح لوحة البائع.
- يرسل البائع المنتجات إلى المراجعة؛ تحدد الإدارة السعر وتعتمد النشر، ثم يتحكم البائع بالتوافر اليدوي.
- لا توجد كميات مخزون، ولا دفع إلكتروني في الإصدار الأول. الإنتاج يتطلب HTTPS وإعدادات JWT وCORS المناسبة.


## إعداد إصدار Android حقيقي

- أنشئ Android OAuth client لهذا التطبيق بمعرّف الحزمة `com.alqlaisi.seller` وبصمة SHA-1 الصحيحة.
- ملفات `seller_app/android/gradlew` و`gradle-wrapper.jar` موجودة الآن في المستودع، ويمكن بناء APK التطوير عبر `flutter build apk --debug`.
- إصدار Release لا يُوقّع بمفتاح Debug. اضبط متغيرات `ALQLAISI_SELLER_KEYSTORE_PATH`, `ALQLAISI_SELLER_KEYSTORE_PASSWORD`, `ALQLAISI_SELLER_KEY_ALIAS`, و`ALQLAISI_SELLER_KEY_PASSWORD` في بيئة البناء.
- لا ترفع keystore أو كلمات المرور إلى Git. نجاح تحليل Flutter أو بناء Debug ليس بديلاً عن اختبار التطبيق على جهاز فعلي.
