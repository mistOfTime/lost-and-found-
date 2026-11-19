-- ============================================================
-- RLS FIX — Allow admins to see ALL items and claims
-- Run in Supabase SQL Editor
-- ============================================================

-- Drop old items select policy and replace with clearer one
DROP POLICY IF EXISTS "items_select" ON public.items;

CREATE POLICY "items_select"
  ON public.items FOR SELECT
  USING (
    -- Admins see everything
    public.get_user_role() = 'admin'
    -- Owners see their own items (any status)
    OR reporter_id = auth.uid()
    -- Everyone else sees approved items only
    OR is_approved = TRUE
  );

-- Drop old claims select policy and replace
DROP POLICY IF EXISTS "claims_select" ON public.claims;

CREATE POLICY "claims_select"
  ON public.claims FOR SELECT
  USING (
    -- Admins see all claims
    public.get_user_role() = 'admin'
    -- Claimants see their own claims
    OR claimant_id = auth.uid()
    -- Item reporters see claims on their items
    OR EXISTS (
      SELECT 1 FROM public.items
      WHERE id = item_id AND reporter_id = auth.uid()
    )
  );

-- Allow admin to update any item (approve/reject)
DROP POLICY IF EXISTS "items_update" ON public.items;

CREATE POLICY "items_update"
  ON public.items FOR UPDATE
  USING (
    reporter_id = auth.uid()
    OR public.get_user_role() = 'admin'
  );

SELECT 'RLS fix applied.' AS result;
