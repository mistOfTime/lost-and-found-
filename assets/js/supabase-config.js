/* ============================================================
   WILDCAT LOST & FOUND — Supabase Configuration
   ============================================================
   Only the publishable (anon) key is used here.
   The secret key is NEVER placed in frontend code.
   ============================================================ */

const SUPABASE_URL  = 'YOUR_SUPABASE_PROJECT_URL';
const SUPABASE_ANON = 'YOUR_SUPABASE_PUBLISHABLE_KEY';

// Initialize Supabase client
const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON, {
  auth: {
    autoRefreshToken:   true,
    persistSession:     true,
    detectSessionInUrl: true,
  },
});

/* ============================================================
   SECURITY HELPERS
   ============================================================ */

/**
 * Validate that a URL is safe to redirect to or render as href.
 * Accepts only relative paths (starting with /) or https:// to
 * the same Supabase storage origin. Rejects javascript:, data:,
 * http://, and external hosts.
 */
function isSafeUrl(url) {
  if (!url || typeof url !== 'string') return false;
  // Allow relative paths
  if (url.startsWith('/')) return true;
  // Allow Supabase storage URLs only
  try {
    const parsed = new URL(url);
    return parsed.protocol === 'https:' &&
           parsed.hostname.endsWith('.supabase.co');
  } catch (_) {
    return false;
  }
}

/**
 * Returns a safe href string — empty string if URL is unsafe.
 */
function safeHref(url) {
  return isSafeUrl(url) ? url : '#';
}

/* ============================================================
   AUTH HELPERS
   ============================================================ */

/** Returns the authenticated Supabase user, or null. */
async function getCurrentUser() {
  const { data: { user } } = await supabaseClient.auth.getUser();
  return user;
}

/**
 * Fetches the profile row for a user ID.
 * Returns null if not found.
 */
async function getUserProfile(userId) {
  const { data, error } = await supabaseClient
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();
  if (error) { console.error('getUserProfile:', error.message); return null; }
  return data;
}

/**
 * Protects a page by role AND status.
 *
 * Usage:  requireAuth(['student', 'faculty'])
 *         requireAuth(['admin'])
 *
 * - Unauthenticated → login page
 * - Suspended account → sign out + login page
 * - Wrong role → own dashboard
 */
async function requireAuth(allowedRoles = []) {
  const user = await getCurrentUser();
  if (!user) {
    redirectTo('/pages/login.html');
    return null;
  }

  const profile = await getUserProfile(user.id);
  if (!profile) {
    redirectTo('/pages/login.html');
    return null;
  }

  // Block suspended accounts on every protected page
  if (profile.status === 'suspended') {
    await supabaseClient.auth.signOut();
    redirectTo('/pages/login.html');
    return null;
  }

  // Block pending admin accounts from accessing any dashboard
  if (profile.status === 'pending') {
    await supabaseClient.auth.signOut();
    redirectTo('/pages/login.html');
    return null;
  }

  if (allowedRoles.length > 0 && !allowedRoles.includes(profile.role)) {
    redirectToDashboard(profile.role);
    return null;
  }

  return { user, profile };
}

/** Redirects to the correct dashboard for the given role. */
function redirectToDashboard(role) {
  const map = {
    student: '/dashboards/student.html',
    faculty: '/dashboards/faculty.html',
    admin:   '/dashboards/admin.html',
  };
  redirectTo(map[role] || '/index.html');
}

/**
 * Safe redirect — only allows paths starting with /.
 * Falls back to relative path when running from file://.
 */
function redirectTo(path) {
  // Guard: path must start with /
  if (!path || !path.startsWith('/')) {
    console.error('redirectTo: invalid path', path);
    return;
  }
  const base = window.location.protocol === 'file:' ? '.' : '';
  window.location.href = base + path;
}

/** Base path prefix for pages in subdirectories. */
function getBasePath() {
  const p = window.location.pathname;
  if (p.includes('/pages/') || p.includes('/dashboards/') || p.includes('/admin/')) {
    return '../';
  }
  return '';
}

/* ============================================================
   SIGN-OUT
   ============================================================ */
async function signOut() {
  await supabaseClient.auth.signOut();
  redirectTo('/pages/login.html');
}

document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('[data-action="signout"]').forEach(el => {
    el.addEventListener('click', e => { e.preventDefault(); signOut(); });
  });
});
