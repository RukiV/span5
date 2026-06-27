// Global logout interceptor
// If any element navigates to /login (anchor or Link), ensure we clear session state first

(function() {
  function findAnchorHref(el) {
    while (el) {
      if (el.tagName === 'A' && el.getAttribute) return el.getAttribute('href');
      el = el.parentElement;
    }
    return null;
  }

  function handleClick(e) {
    try {
      const href = findAnchorHref(e.target);
      if (!href) return;
      // Normalize
      const url = href.split('?')[0];
      if (url === '/login' || url.endsWith('/login')) {
        // Prevent default navigation, clear storage, then navigate
        e.preventDefault();
        try { sessionStorage.clear(); localStorage.clear(); } catch(_) {}
        // Use replace to prevent back navigation
        window.location.replace(window.location.origin + '/login');
      }
    } catch (err) {
      // ignore
      console.error('logoutInterceptor error', err);
    }
  }

  document.addEventListener('click', handleClick, true);
  
  // Replace any existing anchors that point to /login with a safe button
  function replaceLoginAnchors() {
    try {
      const anchors = Array.from(document.querySelectorAll('a.btn-logout-sidebar'));
      anchors.forEach(a => {
        const href = a.getAttribute('href') || '';
        if (href.split('?')[0] === '/login') {
          const btn = document.createElement('button');
          btn.type = 'button';
          btn.className = a.className;
          btn.textContent = a.textContent || 'Logout';
          btn.addEventListener('click', (e) => {
            e.preventDefault();
            try { sessionStorage.clear(); localStorage.clear(); } catch(_) {}
            window.location.replace(window.location.origin + '/login');
          });
          a.parentNode.replaceChild(btn, a);
        }
      });
    } catch (err) { /* ignore */ }
  }

  // Run on next tick and on DOM changes
  setTimeout(replaceLoginAnchors, 50);
  const obs = new MutationObserver(replaceLoginAnchors);
  obs.observe(document.body, { childList: true, subtree: true });
})();
