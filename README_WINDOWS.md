# دليل تشغيل منصة القليسي على Windows

هذا الدليل يطابق بنية المستودع الحالية. لم يُنشر الخادم على نطاق عام بمجرد وجود ملفات Docker وNginx.

## تشغيل الخادم

من PowerShell في جذر المستودع:

```powershell
py -3.12 -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r backend/requirements.txt
Copy-Item .env.example .env
python -m uvicorn backend.app.main:app --reload --host 127.0.0.1 --port 8000
```

اترك `DATABASE_URL` فارغاً للتطوير المحلي لاستخدام SQLite. توثيق API على `http://127.0.0.1:8000/docs` خاص بالتطوير فقط.

## تطبيق العميل

من جذر المستودع:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

استخدم `10.0.2.2` لمحاكي Android، و`http://127.0.0.1:8000/api` لتطبيق Windows desktop.

## تطبيق البائع

```powershell
cd seller_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

## لوحة الإدارة

من جذر المستودع:

```powershell
python -m http.server 5500
```

ثم افتح `http://localhost:5500/admin_dashboard/` وسجّل الدخول بحساب مدير مُنشأ مسبقاً على الخادم.

## ما يلزم قبل الإنتاج

أنشئ OAuth clients الفعلية واضبط SHA-1 للتوقيع، وجهّز PostgreSQL مع TLS، وسر JWT، وCORS، وأسماء المضيفين، وشهادة HTTPS، ومفتاح توقيع Release منفصل. انظر `backend/deployment/PRODUCTION_CHECKLIST.md`. نجاح التحليل أو بناء Debug لا يثبت صلاحية Google OAuth الحقيقي ولا يعني أن الاستضافة مباشرة.
