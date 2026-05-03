# 🔄 Firebase → Supabase Migration Plan
## SpotIt AI — Complete Backend Migration

> [!IMPORTANT]
> This is a **full backend replacement**. Every file that touches Firebase must be rewritten. The UI files stay the same — only the data/service layer changes.

---

## 📊 What Changes vs What Stays

| Layer | Firebase (Current) | Supabase (New) | Changes? |
|---|---|---|---|
| Database | Realtime Database (NoSQL/JSON) | PostgreSQL (relational tables) | ✅ Full rewrite |
| Storage | Firebase Storage | Supabase Storage | ✅ Full rewrite |
| Auth | Custom (passwords in DB) | Supabase Auth (email+password) | ✅ Full rewrite |
| Real-time | `onValue` streams | Supabase Realtime (channels) | ✅ Rewrite |
| UI Pages | Flutter widgets | Flutter widgets | ❌ Unchanged |
| Models | `issue_model.dart`, `post_model.dart` | Same + `fromMap()` | 🔧 Minor update |
| User session | `user_service.dart` | `user_service.dart` | 🔧 Minor update |

---

## 🗃️ Phase 1 — Supabase Project Setup

### 1.1 Create Project
1. Go to [supabase.com](https://supabase.com) → **New Project**
2. Note your:
   - **Project URL**: `https://xxxx.supabase.co`
   - **Anon key**: `eyJh...`

### 1.2 Create Tables (Run in SQL Editor)

```sql
-- Users table (replaces Firebase 'users' node)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  username TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL DEFAULT 'Student',       -- 'Student' | 'Admin'
  department TEXT,
  admin_type TEXT,
  employee_id TEXT,
  user_type TEXT,
  profile_complete BOOLEAN DEFAULT FALSE,
  email_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Issues table (replaces Firebase 'issues' node)
CREATE TABLE issues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  class_name TEXT NOT NULL,
  severity TEXT NOT NULL,
  confidence FLOAT8 NOT NULL DEFAULT 0,
  latitude FLOAT8 NOT NULL DEFAULT 0,
  longitude FLOAT8 NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  image_url TEXT,
  detected_image_url TEXT,
  upvotes INT DEFAULT 0,
  downvotes INT DEFAULT 0,
  reported_by UUID REFERENCES users(id),
  reported_at TIMESTAMPTZ DEFAULT NOW()
);

-- Votes table (replaces nested 'votes' map in issues)
CREATE TABLE issue_votes (
  issue_id UUID REFERENCES issues(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  vote INT NOT NULL CHECK (vote IN (-1, 1)),
  PRIMARY KEY (issue_id, user_id)
);

-- Posts table (replaces Firebase 'posts' node)
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  image_url TEXT NOT NULL,
  description TEXT NOT NULL,
  author_id UUID REFERENCES users(id),
  author_name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Reports table (replaces Firebase 'reports' node)
CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  image_url TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  uploaded_by UUID REFERENCES users(id)
);

-- Issue comments (replaces Firebase 'issue_comments/{key}' node)
CREATE TABLE issue_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  issue_id UUID REFERENCES issues(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  author_id UUID REFERENCES users(id),
  author_name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 1.3 Enable Row Level Security (RLS) — Basic Open Rules
```sql
-- Allow all operations for now (tighten in production)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE issue_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE issue_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all" ON users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON issues FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON issue_votes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON posts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON reports FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON issue_comments FOR ALL USING (true) WITH CHECK (true);
```

### 1.4 Create Storage Buckets
In Supabase Dashboard → Storage → **New Bucket**:
- `issue-images` (public)
- `post-images` (public)
- `report-images` (public)

---

## 📦 Phase 2 — Flutter Dependency Changes

### pubspec.yaml
```yaml
# REMOVE these:
# firebase_core: ^4.3.0
# firebase_database: ^12.1.1
# firebase_storage: ^13.0.5
# cloud_firestore: ^6.1.1   ← already unused

# ADD this:
supabase_flutter: ^2.5.0
```

---

## 🛠️ Phase 3 — File-by-File Changes

### Files to DELETE
| File | Reason |
|---|---|
| `lib/firebase_db.dart` | Replaced by Supabase client |
| `lib/firebase_options.dart` | Firebase config — no longer needed |
| `android/app/google-services.json` | Firebase config — no longer needed |

### Files to REWRITE COMPLETELY
| File | What changes |
|---|---|
| `lib/firebase_service.dart` → `lib/supabase_service.dart` | All DB + Storage calls → Supabase |
| `lib/main.dart` | `Firebase.initializeApp()` → `Supabase.initialize()` |
| `lib/login_page.dart` | `dbRef("users")` → `supabase.from('users')` |
| `lib/register_page.dart` | `_db.push().set()` → `supabase.from('users').insert()` |
| `lib/forgot_password.dart` | `orderByChild` query → Supabase query |
| `lib/admin_dashboard.dart` | All `DatabaseReference` streams → Supabase streams |
| `lib/home_page.dart` | All Firebase streams → Supabase streams |
| `lib/report_issue_page.dart` | `FirebaseService` → `SupabaseService` |
| `lib/my_issue_page.dart` | Firebase queries → Supabase queries |
| `lib/track_issues_page.dart` | Firebase queries → Supabase queries |
| `lib/reports_display_page.dart` | Firebase queries → Supabase queries |
| `lib/create_post_page.dart` | `FirebaseService` → `SupabaseService` |

### Files with MINOR UPDATES
| File | What changes |
|---|---|
| `lib/model/issue_model.dart` | Add `fromMap(Map<String, dynamic>)` factory |
| `lib/model/post_model.dart` | Add `fromMap(Map<String, dynamic>)` factory |
| `lib/user_service.dart` | Store Supabase user UUID instead of Firebase push key |

---

## 🔁 Phase 4 — Key API Translation Reference

### Database Operations

| Firebase | Supabase |
|---|---|
| `dbRef('users').get()` | `supabase.from('users').select()` |
| `dbRef('users').push().set(data)` | `supabase.from('users').insert(data)` |
| `dbRef('users').child(key).update(data)` | `supabase.from('users').update(data).eq('id', key)` |
| `dbRef('users').child(key).remove()` | `supabase.from('users').delete().eq('id', key)` |
| `dbRef('issues').onValue` (stream) | `supabase.from('issues').stream(primaryKey: ['id'])` |
| `orderByChild('username').equalTo(val)` | `.eq('username', val)` |
| `runTransaction(...)` (atomic vote) | PostgreSQL function or optimistic update |

### Storage Operations

| Firebase | Supabase |
|---|---|
| `_storage.ref().child(path).putFile(file)` | `supabase.storage.from('bucket').upload(path, file)` |
| `ref.getDownloadURL()` | `supabase.storage.from('bucket').getPublicUrl(path)` |

### Auth (New — Using Supabase Auth)

| Current (custom) | Supabase Auth |
|---|---|
| Store password in RTDB | `supabase.auth.signUp(email, password)` |
| Manual password check | `supabase.auth.signInWithPassword(email, password)` |
| Manual session in SharedPreferences | `supabase.auth.currentSession` (auto-persisted) |
| Manual `UserService.setCurrentUser()` | `supabase.auth.currentUser` |

> [!NOTE]
> With Supabase Auth, you **no longer need to store passwords in the database** or manage sessions manually. Supabase handles this via JWT tokens automatically.

---

## 📋 Phase 5 — Implementation Order

Do these in order to avoid breaking the build:

1. ☐ **Set up Supabase project** (tables + buckets + RLS rules)
2. ☐ **Update `pubspec.yaml`** — remove Firebase packages, add `supabase_flutter`
3. ☐ **Update `main.dart`** — replace Firebase init with Supabase init
4. ☐ **Create `lib/supabase_service.dart`** — full rewrite of `firebase_service.dart`
5. ☐ **Update models** — add `fromMap()` factories
6. ☐ **Update `login_page.dart`** — Supabase Auth sign-in
7. ☐ **Update `register_page.dart`** — Supabase Auth sign-up + insert user profile
8. ☐ **Update `forgot_password.dart`**
9. ☐ **Update `home_page.dart`** — replace streams
10. ☐ **Update `admin_dashboard.dart`** — replace streams
11. ☐ **Update remaining pages** (`report_issue_page`, `my_issue_page`, etc.)
12. ☐ **Delete Firebase files** (`firebase_db.dart`, `firebase_options.dart`, `google-services.json`)
13. ☐ **Test & run** `flutter clean && flutter pub get && flutter run`

---

## ⚠️ Important Differences to Note

| Topic | Firebase | Supabase |
|---|---|---|
| **IDs** | Auto-generated push keys like `-OB3ab...` | UUID like `550e8400-...` |
| **Real-time** | WebSocket streams built-in | Requires enabling Realtime in dashboard per table |
| **Votes** | Nested map inside issue JSON | Separate `issue_votes` table (cleaner) |
| **Auth** | Custom (passwords in DB) | Native email/password Auth |
| **Offline** | Limited offline support | No built-in offline (can add `drift` for local cache) |
| **Pricing** | Pay-per-use (can get expensive) | Free tier: 500MB DB, 1GB Storage, 50MB file uploads |

---

## ✅ Shall I start implementing?

Reply **"yes, start"** and I'll implement all files in order, starting from `pubspec.yaml` → `main.dart` → `supabase_service.dart` → pages.

Or tell me if you want to start with just one specific file.
