// Search functionality
(function() {
    'use strict';

    var searchModal = document.getElementById('search-modal');
    var searchInput = document.getElementById('search-input');
    var searchResults = document.getElementById('search-results');
    
    if (!searchModal || !searchInput || !searchResults) {
        return;
    }

    // Initialize search when search index is loaded
    if (typeof Worker !== 'undefined') {
        var searchWorker = new Worker(base_url + '/search/worker.js');
        
        searchWorker.onmessage = function(e) {
            var results = e.data.results;
            displayResults(results);
        };

        searchInput.addEventListener('input', function() {
            var query = this.value.trim();
            if (query.length > 2) {
                searchWorker.postMessage({
                    query: query,
                    limit: 10
                });
            } else {
                searchResults.innerHTML = '';
            }
        });
    }

    function displayResults(results) {
        if (results.length === 0) {
            searchResults.innerHTML = '<div class="fluent-search-no-results">No results found</div>';
            return;
        }

        var html = results.map(function(result) {
            return [
                '<div class="fluent-search-result">',
                '<div class="fluent-search-result-title">',
                '<a href="' + result.location + '">' + result.title + '</a>',
                '</div>',
                '<div class="fluent-search-result-snippet">',
                result.summary || result.text.substring(0, 150) + '...',
                '</div>',
                '</div>'
            ].join('');
        }).join('');

        searchResults.innerHTML = html;
    }

    // Handle search result clicks
    searchResults.addEventListener('click', function(e) {
        var link = e.target.closest('a');
        if (link) {
            searchModal.classList.remove('active');
        }
    });
})();
