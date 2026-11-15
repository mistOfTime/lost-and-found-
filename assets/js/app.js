/* ============================================================
   WILDCAT LOST & FOUND — Global App Utilities
   ============================================================ */

'use strict';

/* ============================================================
   TOAST NOTIFICATION SYSTEM
   ============================================================ */
(function setupToasts() {
  let container = document.getElementById('wlf-toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'wlf-toast-container';
    container.className = 'wlf-toast-container';
    document.body.appendChild(container);
  }

  window.showToast = function (message, type = 'info', duration = 3500) {
    const icons = { success: 'fa-check-circle', error: 'fa-times-circle', info: 'fa-info-circle', warning: 'fa-exclamation-circle' };
    const toast = document.createElement('div');
    toast.className = `wlf-toast ${type}`;
    toast.innerHTML = `<i class="fa-solid ${icons[type] || icons.info}"></i><span>${message}</span>`;
    container.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateY(10px)';
      toast.style.transition = 'opacity .3s, transform .3s';
      setTimeout(() => toast.remove(), 300);
    }, duration);
  };
})();

/* ============================================================
   PAGE LOADER
   ============================================================ */
window.showLoader = function () {
  let el = document.getElementById('wlf-page-loader');
  if (!el) {
    el = document.createElement('div');
    el.id = 'wlf-page-loader';
    el.className = 'page-loader';
    el.innerHTML = `
      <div class="loader-inner">
        <div class="loader-spin"></div>
        <p style="color:var(--primary);font-weight:600;font-size:.9rem;margin:0">Loading…</p>
      </div>`;
    document.body.appendChild(el);
  }
  el.style.display = 'flex';
};

window.hideLoader = function () {
  const el = document.getElementById('wlf-page-loader');
  if (el) el.style.display = 'none';
};

/* ============================================================
   SIDEBAR TOGGLE (mobile)
   ============================================================ */
document.addEventListener('DOMContentLoaded', () => {
  const toggleBtn = document.getElementById('sidebar-toggle');
  const sidebar   = document.getElementById('app-sidebar');
  const overlay   = document.getElementById('sidebar-overlay');

  if (toggleBtn && sidebar) {
    toggleBtn.addEventListener('click', () => {
      sidebar.classList.toggle('open');
      overlay && overlay.classList.toggle('show');
    });
  }
  if (overlay) {
    overlay.addEventListener('click', () => {
      sidebar && sidebar.classList.remove('open');
      overlay.classList.remove('show');
    });
  }

  // Highlight active sidebar link
  const links = document.querySelectorAll('.sidebar-link');
  links.forEach(link => {
    if (link.href === window.location.href) {
      link.classList.add('active');
    }
  });
});

/* ============================================================
   INPUT VALIDATION HELPERS
   ============================================================ */
window.validateEmail = (email) =>
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());

window.validatePassword = (pw) => pw.length >= 8;

window.sanitize = (str) =>
  String(str).replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/* Show validation error under a field */
window.showFieldError = function (fieldId, message) {
  const field = document.getElementById(fieldId);
  if (!field) return;
  field.classList.add('is-invalid');
  let err = field.parentElement.querySelector('.field-error');
  if (!err) {
    err = document.createElement('div');
    err.className = 'field-error';
    err.style.cssText = 'font-size:.78rem;color:#dc2626;margin-top:.25rem;';
    field.parentElement.appendChild(err);
  }
  err.textContent = message;
};

window.clearFieldError = function (fieldId) {
  const field = document.getElementById(fieldId);
  if (!field) return;
  field.classList.remove('is-invalid');
  const err = field.parentElement.querySelector('.field-error');
  if (err) err.remove();
};

window.clearAllErrors = function (formId) {
  const form = document.getElementById(formId);
  if (!form) return;
  form.querySelectorAll('.field-error').forEach(e => e.remove());
  form.querySelectorAll('.is-invalid').forEach(e => e.classList.remove('is-invalid'));
};

/* ============================================================
   DATE / TIME FORMATTERS
   ============================================================ */
window.formatDate = function (isoString) {
  if (!isoString) return '—';
  return new Date(isoString).toLocaleDateString('en-PH', {
    year: 'numeric', month: 'short', day: 'numeric',
  });
};

window.formatDateTime = function (isoString) {
  if (!isoString) return '—';
  return new Date(isoString).toLocaleString('en-PH', {
    year: 'numeric', month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
};

window.timeAgo = function (isoString) {
  if (!isoString) return '';
  const diff = Date.now() - new Date(isoString).getTime();
  const mins  = Math.floor(diff / 60000);
  const hrs   = Math.floor(diff / 3600000);
  const days  = Math.floor(diff / 86400000);
  if (mins < 1)  return 'just now';
  if (mins < 60) return `${mins}m ago`;
  if (hrs  < 24) return `${hrs}h ago`;
  if (days < 7)  return `${days}d ago`;
  return formatDate(isoString);
};

/* ============================================================
   CATEGORY & LOCATION CONSTANTS (match DB)
   ============================================================ */
window.ITEM_CATEGORIES = [
  'Electronics', 'Clothing & Accessories', 'Books & Notes',
  'ID & Cards', 'Bags & Backpacks', 'Keys',
  'Jewelry & Watches', 'Sports Equipment', 'School Supplies', 'Other',
];

window.CAMPUS_LOCATIONS = [
  'Main Building', 'Library', 'Gymnasium', 'Canteen',
  'Engineering Building', 'IT Building', 'Science Building',
  'Parking Area', 'Chapel', 'Registrar', 'SSC Office', 'Other',
];

/** Populate a <select> element with options */
window.populateSelect = function (selectId, options, placeholder = 'Select…') {
  const sel = document.getElementById(selectId);
  if (!sel) return;
  sel.innerHTML = `<option value="">${placeholder}</option>`;
  options.forEach(opt => {
    const o = document.createElement('option');
    o.value = typeof opt === 'object' ? opt.value : opt;
    o.textContent = typeof opt === 'object' ? opt.label : opt;
    sel.appendChild(o);
  });
};

/* ============================================================
   IMAGE PREVIEW HELPER
   ============================================================ */
window.previewImage = function (inputId, previewId) {
  const input   = document.getElementById(inputId);
  const preview = document.getElementById(previewId);
  if (!input || !preview) return;

  input.addEventListener('change', () => {
    const file = input.files[0];
    if (!file) return;
    if (!file.type.startsWith('image/')) {
      showToast('Please select an image file.', 'error');
      input.value = '';
      return;
    }
    if (file.size > 5 * 1024 * 1024) {
      showToast('Image must be smaller than 5 MB.', 'error');
      input.value = '';
      return;
    }
    const reader = new FileReader();
    reader.onload = (e) => {
      preview.src = e.target.result;
      preview.style.display = 'block';
    };
    reader.readAsDataURL(file);
  });
};

/* ============================================================
   GENERATE INITIALS for avatar
   ============================================================ */
window.getInitials = function (name) {
  if (!name) return '?';
  const parts = name.trim().split(' ');
  if (parts.length === 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
};

/* ============================================================
   NAVBAR NOTIFICATION BADGE UPDATER
   ============================================================ */
window.updateNotifBadge = async function () {
  const user = await getCurrentUser();
  if (!user) return;
  const { count } = await supabaseClient
    .from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .eq('is_read', false);
  const badge = document.getElementById('notif-badge');
  if (badge) {
    badge.textContent = count || 0;
    badge.style.display = count > 0 ? 'flex' : 'none';
  }
};

/* ============================================================
   REAL-TIME NOTIFICATION LISTENER
   ============================================================ */
window.listenForNotifications = async function () {
  const user = await getCurrentUser();
  if (!user) return;

  supabaseClient
    .channel('public:notifications')
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'notifications',
      filter: `user_id=eq.${user.id}`,
    }, (payload) => {
      showToast(payload.new.message, 'info');
      updateNotifBadge();
    })
    .subscribe();
};

/* ============================================================
   PASSWORD VISIBILITY TOGGLE
   ============================================================ */
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('[data-toggle-pw]').forEach(btn => {
    btn.addEventListener('click', () => {
      const target = document.getElementById(btn.dataset.togglePw);
      if (!target) return;
      const isText = target.type === 'text';
      target.type = isText ? 'password' : 'text';
      btn.querySelector('i').className = isText ? 'fa-solid fa-eye' : 'fa-solid fa-eye-slash';
    });
  });
});

/* ============================================================
   DRAG & DROP UPLOAD ZONE
   ============================================================ */
window.initUploadZone = function (zoneId, inputId) {
  const zone  = document.getElementById(zoneId);
  const input = document.getElementById(inputId);
  if (!zone || !input) return;

  zone.addEventListener('click', () => input.click());
  zone.addEventListener('dragover', e => {
    e.preventDefault();
    zone.classList.add('drag-over');
  });
  zone.addEventListener('dragleave', () => zone.classList.remove('drag-over'));
  zone.addEventListener('drop', e => {
    e.preventDefault();
    zone.classList.remove('drag-over');
    const files = e.dataTransfer.files;
    if (files.length) {
      input.files = files;
      input.dispatchEvent(new Event('change'));
    }
  });
};
