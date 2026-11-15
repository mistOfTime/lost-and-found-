# 🐾 Wildcat Lost & Found
### Official Lost & Found System — Cebu Institute of Technology – University (CIT-U)

---

## Overview

Wildcat Lost & Found is a full-stack web application that lets CIT-U students, faculty, and administrators report lost items, post found belongings, submit ownership claims, and recover property — all through a secure, modern browser-based interface.

**Tech Stack:** HTML5 · CSS3 · Bootstrap 5 · Vanilla JavaScript · Supabase (Auth + DB + Storage) · Font Awesome

---

## Project Structure

```
wildcat-lost-found/
├── index.html                  ← Public homepage
├── supabase_setup.sql          ← Run this first in Supabase SQL Editor
├── README.md
│
├── assets/
│   ├── css/
│   │   └── style.css           ← All custom styles & design tokens
│   ├── js/
│   │   ├── supabase-config.js  ← ⚠️ PUT YOUR KEYS HERE
│   │   └── app.js              ← Global utilities (toast, loader, helpers)
│   └── images/                 ← (empty — add your own images here)
│
├── pages/
│   ├── login.html
│   ├── register.html
│   ├── lost-items.html
│   ├── found-items.html
│   ├── item-details.html
│   ├── report-item.html
│   ├── my-reports.html
│   ├── my-claims.html
│   ├── notifications.html
│   ├── messages.html
│   └── profile.html
│
├── dashboards/
│   ├── student.html
│   ├── faculty.html
│   └── admin.html
│
└── admin/
    ├── users.html              ← Admin: manage accounts
    ├── items.html              ← Admin: approve/reject items
    ├── claims.html             ← Admin: review claims
    └── reports.html            ← Admin: analytics & activity log
```

---

## ⚙️ Setup Instructions

### Step 1 — Create a Supabase Project

1. Go to [https://supabase.com](https://supabase.com) and sign in (or create a free account).
2. Click **New project**.
3. Fill in: **Project Name** = `wildcat-lost-found`, choose a database password, select a region close to Philippines (e.g. Singapore).
4. Wait for the project to finish setting up (~1 minute).

### Step 2 — Run the SQL Setup

1. In your Supabase project dashboard, click **SQL Editor** (left sidebar).
2. Click **New query**.
3. Open `supabase_setup.sql` from this project folder.
4. Copy the **entire contents** and paste into the SQL Editor.
5. Click **Run** (or press Ctrl+Enter).
6. You should see "Success" at the bottom. All tables, RLS policies, storage buckets, and triggers are now created.

### Step 3 — Configure Your API Keys

1. In Supabase, go to **Settings** → **API Keys**.
2. Copy:
   - **Project URL** (e.g. `https://xyzabc.supabase.co`)
   - **Publishable** key (starts with `sb_publishable_...`)
3. Open `assets/js/supabase-config.js` and replace the placeholder values:

```javascript
const SUPABASE_URL  = 'https://YOUR-PROJECT-ID.supabase.co';
const SUPABASE_ANON = 'sb_publishable_...';
```

> ⚠️ **Never** commit real keys to GitHub. Add `supabase-config.js` to `.gitignore` or use environment variables if deploying publicly.

### Step 4 — Configure Authentication

1. In Supabase, go to **Authentication** → **Providers**.
2. Ensure **Email** is enabled.
3. (Optional) To enable **Google Sign-In**:
   - Create OAuth credentials at [console.cloud.google.com](https://console.cloud.google.com).
   - Add Client ID and Secret in Supabase → Auth → Providers → Google.
4. (Recommended for production) Set a **redirect URL** under Auth → URL Configuration:
   ```
   http://localhost:5500/pages/login.html
   ```

### Step 5 — Open the Website

**Option A — VS Code Live Server (recommended)**
1. Install the **Live Server** extension in VS Code.
2. Right-click `index.html` → **Open with Live Server**.
3. The site opens at `http://127.0.0.1:5500`.

**Option B — Direct file**
1. Double-click `index.html`.
2. Note: some browsers restrict local `file://` requests. Use Live Server for best results.

**Option C — Any static web host**
Upload all files to Netlify, Vercel, GitHub Pages, or any shared hosting. No server-side code is needed.

---

## 👤 Test Accounts

After setup, **register** yourself through the UI.

To create the **first admin account**:
1. Register normally and choose "Administrator".
2. In Supabase → Table Editor → `profiles`, find your row.
3. Set `role` = `admin` and `status` = `active`.
4. Log in again — you'll be redirected to the Admin Dashboard.

---

## 🔒 Security Model

| Feature | Implementation |
|---|---|
| Authentication | Supabase Auth (email + optional Google OAuth) |
| Role-based access | Checked on every dashboard via `requireAuth()` in `supabase-config.js` |
| Row Level Security | Every table has RLS policies in `supabase_setup.sql` |
| Private claim evidence | Stored in private `claim-evidence` bucket; only admins & the claimant can read |
| Item images | Stored in public `item-images` bucket |
| Input sanitization | All user data passed through `sanitize()` before DOM insertion |
| Service-role key | Never used in frontend code |

---

## 📄 Pages Reference

| URL | Description | Auth Required |
|---|---|---|
| `/index.html` | Public homepage with search | No |
| `/pages/login.html` | Login form | No |
| `/pages/register.html` | Registration form | No |
| `/pages/lost-items.html` | Browseable lost items | No |
| `/pages/found-items.html` | Browseable found items | No |
| `/pages/item-details.html?id=...` | Item detail + claim button | No (claim requires auth) |
| `/pages/report-item.html` | Report lost or found item | Yes |
| `/pages/my-reports.html` | View & delete your reports | Yes |
| `/pages/my-claims.html` | Track your claim statuses | Yes |
| `/pages/notifications.html` | View & clear notifications | Yes |
| `/pages/messages.html` | Private messaging | Yes |
| `/pages/profile.html` | Edit profile & change password | Yes |
| `/dashboards/student.html` | Student dashboard | Student / Admin |
| `/dashboards/faculty.html` | Faculty dashboard | Faculty / Admin |
| `/dashboards/admin.html` | Admin overview | Admin only |
| `/admin/users.html` | Manage user accounts | Admin only |
| `/admin/items.html` | Approve/reject item reports | Admin only |
| `/admin/claims.html` | Review ownership claims | Admin only |
| `/admin/reports.html` | Analytics & activity log | Admin only |

---

## 🚀 Phase Completion Status

- [x] **Phase 1** — Project structure, homepage, login, register, Supabase config, SQL setup ✅
- [ ] **Phase 2** — Report item page, image upload, search/filter, listings pages ✅ (included)
- [ ] **Phase 3** — Claim submission, admin claim review, item return
- [ ] **Phase 4** — Messaging, notifications, analytics
- [ ] **Phase 5** — Security testing, mobile polish, deployment

---

## 🛠️ Supabase Storage Buckets

Three buckets are created by the SQL script:

| Bucket | Public | Purpose |
|---|---|---|
| `item-images` | ✅ Yes | Photos of lost/found items |
| `claim-evidence` | ❌ No | Private ownership proof files |
| `avatars` | ✅ Yes | Profile photos |

---

## 📞 Support

Built for the Wildcat community at CIT-U. For questions, contact the system administrator through the Messages section of the application.

---

*Wildcat Lost & Found — Find what you lost. Return what you found.* 🐾
