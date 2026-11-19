-- ============================================================
-- AUTO-APPROVE: Remove pending requirement
-- Users can post freely without admin approval
-- Run in Supabase SQL Editor
-- ============================================================

-- 1. Approve all currently pending items immediately
UPDATE public.items 
SET status = type, is_approved = true
WHERE status = 'pending';

-- 2. Update items RLS so ALL approved items are visible to everyone
DROP POLICY IF EXISTS "items_select" ON public.items;

CREATE POLICY "items_select"
  ON public.items FOR SELECT
  USING (
    -- Admins see everything including rejected
    public.get_user_role() = 'admin'
    -- Owners see their own items
    OR reporter_id = auth.uid()
    -- Everyone sees approved items
    OR is_approved = TRUE
  );

-- 3. Allow any authenticated user to insert with is_approved = true
DROP POLICY IF EXISTS "items_insert_auth" ON public.items;

CREATE POLICY "items_insert_auth"
  ON public.items FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated' 
    AND reporter_id = auth.uid()
  );

SELECT 'Auto-approve applied. ' || COUNT(*) || ' items approved.' AS result
FROM public.items WHERE is_approved = true;

-- Fix item_images RLS so images are visible to everyone
DROP POLICY IF EXISTS "item_images_select" ON public.item_images;
CREATE POLICY "item_images_select"
  ON public.item_images FOR SELECT USING (TRUE);

-- Fix item_images INSERT policy so any authenticated user can insert their own item images
DROP POLICY IF EXISTS "item_images_insert" ON public.item_images;
CREATE POLICY "item_images_insert"
  ON public.item_images FOR INSERT
  WITH CHECK (
    auth.role() = 'authenticated'
  );
