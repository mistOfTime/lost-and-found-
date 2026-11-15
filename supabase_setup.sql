-- ============================================================
-- WILDCAT LOST & FOUND — Supabase Database Setup
-- Cebu Institute of Technology – University
-- ============================================================
-- Run this entire file in the Supabase SQL Editor:
-- Dashboard → SQL Editor → New query → Paste → Run
-- ============================================================

-- Enable UUID extension (usually already enabled on Supabase)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. PROFILES
--    Extends Supabase auth.users with app-level user data.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name     TEXT NOT NULL,
    school_id     TEXT NOT NULL,
    email         TEXT NOT NULL UNIQUE,
    department    TEXT,
    role          TEXT NOT NULL DEFAULT 'student'
                  CHECK (role IN ('student', 'faculty', 'admin')),
    status        TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'suspended', 'pending')),
    avatar_url    TEXT,
    phone         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- 2. LOCATIONS  (campus location reference)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.locations (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL UNIQUE,
    building    TEXT,
    description TEXT,
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default campus locations
INSERT INTO public.locations (name) VALUES
  ('Main Building'),
  ('Library'),
  ('Gymnasium'),
  ('Canteen'),
  ('Engineering Building'),
  ('IT Building'),
  ('Science Building'),
  ('Parking Area'),
  ('Chapel'),
  ('Registrar'),
  ('SSC Office'),
  ('Other')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- 3. ITEMS  (lost and found reports)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type            TEXT NOT NULL CHECK (type IN ('lost', 'found')),
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'lost', 'found', 'claimed', 'returned', 'rejected')),
    name            TEXT NOT NULL,
    category        TEXT NOT NULL,
    description     TEXT,
    location        TEXT NOT NULL,
    date_occurred   DATE NOT NULL,
    brand           TEXT,
    color           TEXT,
    distinguishing_features TEXT,
    is_approved     BOOLEAN NOT NULL DEFAULT FALSE,
    approved_by     UUID REFERENCES public.profiles(id),
    approved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE TRIGGER items_updated_at
  BEFORE UPDATE ON public.items
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_items_reporter   ON public.items(reporter_id);
CREATE INDEX IF NOT EXISTS idx_items_type       ON public.items(type);
CREATE INDEX IF NOT EXISTS idx_items_status     ON public.items(status);
CREATE INDEX IF NOT EXISTS idx_items_category   ON public.items(category);
CREATE INDEX IF NOT EXISTS idx_items_created_at ON public.items(created_at DESC);

-- ============================================================
-- 4. ITEM_IMAGES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.item_images (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id     UUID NOT NULL REFERENCES public.items(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,          -- path inside Supabase Storage bucket
    url         TEXT NOT NULL,           -- public URL
    is_primary  BOOLEAN NOT NULL DEFAULT FALSE,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_item_images_item_id ON public.item_images(item_id);

-- ============================================================
-- 5. CLAIMS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.claims (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id         UUID NOT NULL REFERENCES public.items(id) ON DELETE CASCADE,
    claimant_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    ownership_proof TEXT,          -- private description of proof
    evidence_url    TEXT,          -- Supabase Storage path (private)
    admin_notes     TEXT,          -- visible only to admins
    reviewed_by     UUID REFERENCES public.profiles(id),
    reviewed_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (item_id, claimant_id)  -- one claim per user per item
);

CREATE OR REPLACE TRIGGER claims_updated_at
  BEFORE UPDATE ON public.claims
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE INDEX IF NOT EXISTS idx_claims_item_id     ON public.claims(item_id);
CREATE INDEX IF NOT EXISTS idx_claims_claimant_id ON public.claims(claimant_id);
CREATE INDEX IF NOT EXISTS idx_claims_status      ON public.claims(status);

-- ============================================================
-- 6. MESSAGES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.messages (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content     TEXT NOT NULL,
    is_read     BOOLEAN NOT NULL DEFAULT FALSE,
    item_id     UUID REFERENCES public.items(id) ON DELETE SET NULL,  -- optional link
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_sender   ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver ON public.messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_created  ON public.messages(created_at DESC);

-- ============================================================
-- 7. NOTIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type        TEXT NOT NULL,       -- e.g. 'claim_submitted', 'item_approved', etc.
    message     TEXT NOT NULL,
    link        TEXT,                -- optional URL to navigate to
    is_read     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifs_user_id    ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifs_is_read    ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifs_created_at ON public.notifications(created_at DESC);

-- ============================================================
-- 8. ITEM_RETURNS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.item_returns (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id         UUID NOT NULL UNIQUE REFERENCES public.items(id) ON DELETE CASCADE,
    claim_id        UUID REFERENCES public.claims(id) ON DELETE SET NULL,
    returned_to     UUID NOT NULL REFERENCES public.profiles(id),
    returned_by     UUID NOT NULL REFERENCES public.profiles(id),  -- admin who processed
    return_notes    TEXT,
    return_date     DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_returns_item_id ON public.item_returns(item_id);

-- ============================================================
-- 9. ACTIVITY_LOGS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action      TEXT NOT NULL,       -- 'login', 'report', 'claim', 'approve', 'reject', 'return'
    description TEXT,
    entity_type TEXT,                -- 'item', 'claim', 'user', etc.
    entity_id   UUID,
    ip_address  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_logs_user_id    ON public.activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_logs_action     ON public.activity_logs(action);
CREATE INDEX IF NOT EXISTS idx_logs_created_at ON public.activity_logs(created_at DESC);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE public.profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locations    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.items        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_images  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.claims       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- ---- Helper: get current user role ----
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- ============================================================
-- PROFILES POLICIES
-- ============================================================
-- Users can read their own profile; admins can read all.
CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (id = auth.uid() OR public.get_user_role() = 'admin');

-- Users can update their own profile.
CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid());

-- New users can insert their own profile row.
CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT
  WITH CHECK (id = auth.uid());

-- Only admins can delete profiles.
CREATE POLICY "profiles_delete_admin"
  ON public.profiles FOR DELETE
  USING (public.get_user_role() = 'admin');

-- ============================================================
-- LOCATIONS POLICIES (public read, admin write)
-- ============================================================
CREATE POLICY "locations_select_all"
  ON public.locations FOR SELECT USING (TRUE);

CREATE POLICY "locations_insert_admin"
  ON public.locations FOR INSERT
  WITH CHECK (public.get_user_role() = 'admin');

CREATE POLICY "locations_update_admin"
  ON public.locations FOR UPDATE
  USING (public.get_user_role() = 'admin');

CREATE POLICY "locations_delete_admin"
  ON public.locations FOR DELETE
  USING (public.get_user_role() = 'admin');

-- ============================================================
-- ITEMS POLICIES
-- ============================================================
-- Approved items are publicly readable; pending/rejected only by owner or admin.
CREATE POLICY "items_select"
  ON public.items FOR SELECT
  USING (
    is_approved = TRUE
    OR reporter_id = auth.uid()
    OR public.get_user_role() = 'admin'
  );

-- Authenticated users can insert items.
CREATE POLICY "items_insert_auth"
  ON public.items FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' AND reporter_id = auth.uid());

-- Owners can update their own items; admins can update any.
CREATE POLICY "items_update"
  ON public.items FOR UPDATE
  USING (reporter_id = auth.uid() OR public.get_user_role() = 'admin');

-- Only admins can delete items.
CREATE POLICY "items_delete_admin"
  ON public.items FOR DELETE
  USING (public.get_user_role() = 'admin');

-- ============================================================
-- ITEM_IMAGES POLICIES
-- ============================================================
CREATE POLICY "item_images_select"
  ON public.item_images FOR SELECT USING (TRUE);

CREATE POLICY "item_images_insert"
  ON public.item_images FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.items
      WHERE id = item_id AND reporter_id = auth.uid()
    )
    OR public.get_user_role() = 'admin'
  );

CREATE POLICY "item_images_delete"
  ON public.item_images FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.items
      WHERE id = item_id AND reporter_id = auth.uid()
    )
    OR public.get_user_role() = 'admin'
  );

-- ============================================================
-- CLAIMS POLICIES
-- ============================================================
-- Claimants can see their own claims; item reporters can see claims on their items; admins see all.
CREATE POLICY "claims_select"
  ON public.claims FOR SELECT
  USING (
    claimant_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.items
      WHERE id = item_id AND reporter_id = auth.uid()
    )
    OR public.get_user_role() = 'admin'
  );

-- Authenticated users can submit claims.
CREATE POLICY "claims_insert"
  ON public.claims FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' AND claimant_id = auth.uid());

-- Claimants can cancel their own claims; admins can approve/reject.
CREATE POLICY "claims_update"
  ON public.claims FOR UPDATE
  USING (claimant_id = auth.uid() OR public.get_user_role() = 'admin');

CREATE POLICY "claims_delete"
  ON public.claims FOR DELETE
  USING (claimant_id = auth.uid() OR public.get_user_role() = 'admin');

-- ============================================================
-- MESSAGES POLICIES
-- ============================================================
-- Only participants in a conversation can read their messages.
CREATE POLICY "messages_select"
  ON public.messages FOR SELECT
  USING (sender_id = auth.uid() OR receiver_id = auth.uid());

CREATE POLICY "messages_insert"
  ON public.messages FOR INSERT
  WITH CHECK (sender_id = auth.uid());

CREATE POLICY "messages_update"
  ON public.messages FOR UPDATE
  USING (receiver_id = auth.uid());   -- receiver marks as read

CREATE POLICY "messages_delete"
  ON public.messages FOR DELETE
  USING (sender_id = auth.uid() OR public.get_user_role() = 'admin');

-- ============================================================
-- NOTIFICATIONS POLICIES
-- ============================================================
CREATE POLICY "notifs_select_own"
  ON public.notifications FOR SELECT
  USING (user_id = auth.uid() OR public.get_user_role() = 'admin');

CREATE POLICY "notifs_insert_admin_or_service"
  ON public.notifications FOR INSERT
  WITH CHECK (public.get_user_role() = 'admin');
  -- DB triggers use SECURITY DEFINER and bypass RLS, so they still work.
  -- Regular users cannot insert notifications directly.

CREATE POLICY "notifs_update_own"
  ON public.notifications FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "notifs_delete_admin"
  ON public.notifications FOR DELETE
  USING (public.get_user_role() = 'admin');

-- ============================================================
-- ITEM_RETURNS POLICIES
-- ============================================================
CREATE POLICY "returns_select"
  ON public.item_returns FOR SELECT
  USING (
    returned_to = auth.uid()
    OR public.get_user_role() = 'admin'
  );

CREATE POLICY "returns_insert_admin"
  ON public.item_returns FOR INSERT
  WITH CHECK (public.get_user_role() = 'admin');

CREATE POLICY "returns_update_admin"
  ON public.item_returns FOR UPDATE
  USING (public.get_user_role() = 'admin');

-- ============================================================
-- ACTIVITY_LOGS POLICIES
-- ============================================================
CREATE POLICY "logs_select_admin"
  ON public.activity_logs FOR SELECT
  USING (public.get_user_role() = 'admin');

CREATE POLICY "logs_insert_auth"
  ON public.activity_logs FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());
  -- Users can only write log entries attributed to themselves.

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================
-- Run these in Supabase Dashboard → Storage, OR via SQL:

INSERT INTO storage.buckets (id, name, public)
VALUES ('item-images', 'item-images', TRUE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('claim-evidence', 'claim-evidence', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS policies
CREATE POLICY "item_images_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'item-images');

CREATE POLICY "item_images_auth_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'item-images' AND auth.role() = 'authenticated');

CREATE POLICY "item_images_owner_delete"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'item-images' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Claim evidence: only admins and the claimant can read
CREATE POLICY "claim_evidence_private_select"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'claim-evidence'
    AND (
      public.get_user_role() = 'admin'
      OR auth.uid()::text = (storage.foldername(name))[1]
    )
  );

CREATE POLICY "claim_evidence_auth_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'claim-evidence' AND auth.role() = 'authenticated');

CREATE POLICY "avatars_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

CREATE POLICY "avatars_auth_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

-- ============================================================
-- SECURITY: Block admin role self-assignment from client
-- Only an existing admin (service-role) can set role = 'admin'
-- ============================================================
CREATE OR REPLACE FUNCTION public.prevent_admin_self_assign()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- On INSERT from client (not service role), block admin role
  IF NEW.role = 'admin' THEN
    -- Allow only if caller is service role
    IF current_setting('request.jwt.claims', true)::json->>'role' != 'service_role' THEN
      NEW.role := 'student';  -- silently downgrade to student
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER enforce_no_admin_self_register
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_admin_self_assign();

-- Also prevent clients from changing their own role to admin via UPDATE
CREATE OR REPLACE FUNCTION public.prevent_role_escalation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.role != OLD.role THEN
    -- Only service role can change roles
    IF current_setting('request.jwt.claims', true)::json->>'role' != 'service_role' THEN
      NEW.role := OLD.role;  -- revert role change
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER enforce_no_role_escalation
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_role_escalation();

-- ============================================================
-- Auto-create profile row when a new auth user signs up via trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role, school_id)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User'),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'student'),
    COALESCE(NEW.raw_user_meta_data->>'school_id', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Attach trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to send a notification
CREATE OR REPLACE FUNCTION public.send_notification(
  p_user_id UUID,
  p_type    TEXT,
  p_message TEXT,
  p_link    TEXT DEFAULT NULL
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, message, link)
  VALUES (p_user_id, p_type, p_message, p_link);
END;
$$;

-- Function: notify reporter when a claim is submitted
CREATE OR REPLACE FUNCTION public.notify_on_claim()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_item_name TEXT;
  v_reporter  UUID;
BEGIN
  SELECT name, reporter_id INTO v_item_name, v_reporter
  FROM public.items WHERE id = NEW.item_id;

  PERFORM public.send_notification(
    v_reporter,
    'claim_submitted',
    'A new ownership claim was submitted for your item: ' || v_item_name,
    '/admin/claims.html?id=' || NEW.id::text
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_claim_inserted
  AFTER INSERT ON public.claims
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_claim();

-- Function: notify claimant when claim is reviewed
CREATE OR REPLACE FUNCTION public.notify_on_claim_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_item_name TEXT;
BEGIN
  IF OLD.status = 'pending' AND NEW.status IN ('approved', 'rejected') THEN
    SELECT name INTO v_item_name FROM public.items WHERE id = NEW.item_id;

    PERFORM public.send_notification(
      NEW.claimant_id,
      'claim_' || NEW.status,
      'Your claim for "' || v_item_name || '" has been ' || NEW.status || '.',
      '/pages/my-claims.html'
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_claim_reviewed
  AFTER UPDATE ON public.claims
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_claim_review();

-- Function: notify reporter when item is approved/rejected
CREATE OR REPLACE FUNCTION public.notify_on_item_review()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF OLD.is_approved IS DISTINCT FROM NEW.is_approved AND NEW.is_approved = TRUE THEN
    PERFORM public.send_notification(
      NEW.reporter_id,
      'item_approved',
      'Your item report "' || NEW.name || '" has been approved and is now visible.',
      '/pages/item-details.html?id=' || NEW.id::text
    );
  END IF;

  IF OLD.status <> NEW.status AND NEW.status = 'rejected' THEN
    PERFORM public.send_notification(
      NEW.reporter_id,
      'item_rejected',
      'Your item report "' || NEW.name || '" was not approved. Please contact an admin.',
      '/pages/my-reports.html'
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_item_reviewed
  AFTER UPDATE ON public.items
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_item_review();

-- ============================================================
-- REALTIME  (enable for live notifications and messages)
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- ============================================================
-- DONE
-- ============================================================
-- Your Wildcat Lost & Found database is ready.
-- Next steps:
--   1. Configure your Supabase URL and anon key in
--      assets/js/supabase-config.js
--   2. Enable Email Auth in Supabase Dashboard → Auth → Providers
--   3. (Optional) Enable Google OAuth in Auth → Providers
--   4. Open index.html in your browser and test.
-- ============================================================
