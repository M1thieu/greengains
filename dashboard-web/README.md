# GreenGains Analytics Dashboard

Modern React dashboard for GreenGains Smart Cities platform.

## 🚀 Deploy to Hostinger

### 1. Build
Double-click: **`BUILD-FOR-HOSTINGER.bat`**

### 2. Upload
Upload everything from `out/` folder to Hostinger:
- File Manager → `public_html/dashboard/`
- Or via FTP

### 3. Done!
Access at: `https://yourdomain.com/dashboard/`

---

## 📁 Files

```
dashboard-web/
├── app/page.tsx       # Main dashboard
├── lib/api.ts         # API client
└── out/              # Built files (upload this!)
```

## 🛠️ Stack

- Next.js 14 + TypeScript
- Tailwind CSS + shadcn/ui
- Static export (works on any host)

## 📝 To Update

1. Edit `app/page.tsx`
2. Run `BUILD-FOR-HOSTINGER.bat`
3. Re-upload `out/` folder
