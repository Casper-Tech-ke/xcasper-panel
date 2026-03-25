/* XCASPER Docs — Dynamic sidebar extras */
(function () {
    function injectGitCloneLink() {
        // Find the "Updating" menu link in the panel sidebar
        var allLinks = document.querySelectorAll('a.menu__link');
        var updatingLink = null;
        for (var i = 0; i < allLinks.length; i++) {
            if (allLinks[i].href && allLinks[i].href.includes('/docs/panel/updating')) {
                updatingLink = allLinks[i];
                break;
            }
        }
        if (!updatingLink) return;

        // Check if already injected
        var existing = document.querySelector('a[href="/docs/panel/git-clone"]');
        if (existing) return;

        // Build new menu item
        var li = document.createElement('li');
        li.className = 'theme-doc-sidebar-item-link theme-doc-sidebar-item-link-level-1 menu__list-item';
        var a = document.createElement('a');
        a.className = 'menu__link';
        a.href = '/docs/panel/git-clone';
        a.textContent = '🔀 Git Clone';

        // Mark active if on this page
        if (window.location.pathname.includes('/docs/panel/git-clone')) {
            a.className += ' menu__link--active';
            a.setAttribute('aria-current', 'page');
        }

        li.appendChild(a);

        // Insert after the "Updating" list item
        var parentLi = updatingLink.closest('li');
        if (parentLi && parentLi.parentNode) {
            parentLi.parentNode.insertBefore(li, parentLi.nextSibling);
        }
    }

    // Run after Docusaurus hydrates (it replaces the pre-rendered sidebar with React)
    var done = false;
    function tryInject() {
        if (done) return;
        injectGitCloneLink();
        var el = document.querySelector('a[href="/docs/panel/git-clone"]');
        if (el) done = true;
    }

    // MutationObserver to detect React hydration completing
    var observer = new MutationObserver(function () { tryInject(); });
    observer.observe(document.body, { childList: true, subtree: true });

    // Also try on load and after delays
    window.addEventListener('load', tryInject);
    setTimeout(tryInject, 500);
    setTimeout(tryInject, 1500);
    setTimeout(function() { observer.disconnect(); }, 10000);
})();
