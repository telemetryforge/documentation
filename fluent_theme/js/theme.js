// Theme JavaScript
document.addEventListener('DOMContentLoaded', function() {
    // Search modal functionality
    const searchTrigger = document.querySelector('.fluent-search-trigger');
    const searchModal = document.getElementById('search-modal');
    const searchInput = document.getElementById('search-input');

    if (searchTrigger && searchModal) {
        searchTrigger.addEventListener('click', function() {
            searchModal.classList.add('active');
            searchInput.focus();
        });

        // Close modal on escape or outside click
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape' && searchModal.classList.contains('active')) {
                searchModal.classList.remove('active');
            }
        });

        searchModal.addEventListener('click', function(e) {
            if (e.target === searchModal) {
                searchModal.classList.remove('active');
            }
        });
    }

    // Table of contents active state
    const tocLinks = document.querySelectorAll('.fluent-toc a');
    const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');

    function updateTocActiveState() {
        let current = '';
        headings.forEach(heading => {
            const rect = heading.getBoundingClientRect();
            if (rect.top <= 100) {
                current = heading.id;
            }
        });

        tocLinks.forEach(link => {
            link.classList.remove('active');
            if (link.getAttribute('href') === '#' + current) {
                link.classList.add('active');
            }
        });
    }

    window.addEventListener('scroll', updateTocActiveState);
    updateTocActiveState();

    // Mobile sidebar toggle
    const sidebarToggle = document.createElement('button');
    sidebarToggle.className = 'fluent-sidebar-toggle fluent-btn fluent-btn-ghost';
    sidebarToggle.innerHTML = '☰';
    sidebarToggle.style.display = 'none';

    const headerActions = document.querySelector('.fluent-header-actions');
    if (headerActions) {
        headerActions.insertBefore(sidebarToggle, headerActions.firstChild);
    }

    const sidebar = document.querySelector('.fluent-sidebar');
    
    sidebarToggle.addEventListener('click', function() {
        sidebar.classList.toggle('active');
    });

    // Show sidebar toggle on mobile
    function checkMobile() {
        if (window.innerWidth <= 1024) {
            sidebarToggle.style.display = 'inline-flex';
        } else {
            sidebarToggle.style.display = 'none';
            sidebar.classList.remove('active');
        }
    }

    window.addEventListener('resize', checkMobile);
    checkMobile();

    // Smooth scrolling for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
});
