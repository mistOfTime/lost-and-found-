-- ============================================================
-- WILDCAT LOST & FOUND — Security Patch
-- Run this in Supabase SQL Editor if you already ran
-- supabase_setup.sql. This patches the two weak RLS policies
-- and adds the role-escalation prevention triggers.
-- ============================================================

-- 1. Fix notifications INSERT policy (was: WITH CHECK (TRUE))
DROP POLICY IF EXISTS "notifs_insert_admin_or_service" ON public.notifications;
CREATE POLICY "notifs_insert_admin_or_service"
  ON public.notifications FOR INSERT
  WITH CHECK (public.get_user_role() = 'admin');
-- Note: DB triggers use SECURITY DEFINER and bypass RLS — they still work.

-- 2. Fix activity_logs INSERT policy (was: WITH CHECK (TRUE))
DROP POLICY IF EXISTS "logs_insert_auth" ON public.activity_logs;
CREATE POLICY "logs_insert_auth"
  ON public.activity_logs FOR INSERT
  WITH CHECK (auth.role() = 'authenticated' AND user_id = auth.uid());

-- 3. Block admin role self-assignment on INSERT
CREATE OR REPLACE FUNCTION public.prevent_admin_self_assign()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.role = 'admin' THEN
    IF current_setting('request.jwt.claims', true)::json->>'role' != 'service_role' THEN
      NEW.role := 'student';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_no_admin_self_register ON public.profiles;
CREATE TRIGGER enforce_no_admin_self_register
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_admin_self_assign();

-- 4. Block users from escalating their own role via UPDATE
CREATE OR REPLACE FUNCTION public.prevent_role_escalation()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.role != OLD.role THEN
    IF current_setting('request.jwt.claims', true)::json->>'role' != 'service_role' THEN
      NEW.role := OLD.role;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_no_role_escalation ON public.profiles;
CREATE TRIGGER enforce_no_role_escalation
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.prevent_role_escalation();

-- Done.
SELECT 'Security patch applied successfully.' AS result;
