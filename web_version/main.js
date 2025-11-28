const WORKER_GET_URL = 'https://rewards-keyword-worker.sumitomo0210.workers.dev/get';
const WORKER_SAVE_URL = 'https://rewards-keyword-worker.sumitomo0210.workers.dev/save';
const BLOG_URL = 'https://yoshizo.hatenablog.com/entry/microsoft-rewards-search-keyword-list/';
// Using a CORS proxy to allow fetching the blog content from the browser.
// Without this, the browser will block the request to the blog.
const PROXY_URL = 'https://api.allorigins.win/raw?url=';

let fetchedKeywords = {};
let userKeywords = {};
let selectedCategory = null;
let rawJsonResponse = '';

document.addEventListener('DOMContentLoaded', () => {
    initialize();
    setupEventListeners();
});

function setupEventListeners() {
    document.getElementById('category-select').addEventListener('change', (e) => {
        selectedCategory = e.target.value;
    });

    document.getElementById('add-btn').addEventListener('click', addKeyword);
    document.getElementById('save-btn').addEventListener('click', saveKeywordsToKV);

    // Dark mode toggle
    const darkModeBtn = document.getElementById('dark-mode-btn');
    darkModeBtn.addEventListener('click', toggleDarkMode);

    // Load preference
    if (localStorage.getItem('darkMode') === 'true') {
        document.body.classList.add('dark-mode');
    }
    updateDarkModeIcon();
}

function toggleDarkMode() {
    document.body.classList.toggle('dark-mode');
    localStorage.setItem('darkMode', document.body.classList.contains('dark-mode'));
    updateDarkModeIcon();
}

function updateDarkModeIcon() {
    const btn = document.getElementById('dark-mode-btn');
    const isDark = document.body.classList.contains('dark-mode');

    // Sun Icon (for Light Mode -> switch to Dark) or Moon Icon (for Dark Mode -> switch to Light)?
    // Usually: Show Moon when in Light Mode (to indicate "Night Mode"), Show Sun when in Dark Mode (to indicate "Day Mode").
    // Let's stick to: Show what it IS or what it WILL BE?
    // User said "Button doesn't become Moon". 
    // If currently Light, button is Sun (default). User wants it to change.
    // Let's implement: Light Mode = Moon Icon (click to go dark), Dark Mode = Sun Icon (click to go light).

    if (isDark) {
        // Show Sun (to switch to light)
        btn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24" fill="currentColor"><path d="M0 0h24v24H0z" fill="none"/><path d="M20 8.69V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69L23.31 12 20 8.69zM12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6 6 2.69 6 6-2.69 6-6 6zm0-10c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4z"/></svg>';
        btn.title = "Switch to Light Mode";
    } else {
        // Show Moon (to switch to dark)
        btn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24" fill="currentColor"><path d="M0 0h24v24H0z" fill="none"/><path d="M10 2c-1.82 0-3.53.5-5 1.35C7.99 5.08 10 8.3 10 12s-2.01 6.92-5 8.65C6.47 21.5 8.18 22 10 22c5.52 0 10-4.48 10-10S15.52 2 10 2z"/></svg>';
        btn.title = "Switch to Dark Mode";
    }
}

async function initialize() {
    showLoading(true);
    try {
        await Promise.all([fetchUserKeywords(), fetchAndParseWebKeywords()]);
        render();
    } catch (e) {
        showError(e.message);
    } finally {
        showLoading(false);
    }
}

async function fetchUserKeywords() {
    try {
        const response = await fetch(WORKER_GET_URL);
        if (response.ok) {
            const data = await response.json();
            userKeywords = data;
            rawJsonResponse = JSON.stringify(data, null, 2);
            updateRawJsonDisplay();
        } else if (response.status === 404) {
            rawJsonResponse = 'No data found on server (404).';
            updateRawJsonDisplay();
        } else {
            throw new Error(`Failed to load saved keywords: ${response.status}`);
        }
    } catch (e) {
        console.error('Error fetching user keywords:', e);
        rawJsonResponse = `Error connecting to keyword server: ${e.message}`;
        updateRawJsonDisplay();
        // Don't block the app if user keywords fail, just log it
    }
}

async function fetchAndParseWebKeywords() {
    try {
        // Use proxy to bypass CORS
        const response = await fetch(PROXY_URL + encodeURIComponent(BLOG_URL));
        if (!response.ok) throw new Error(`Failed to load web keywords: ${response.status}`);
        const htmlText = await response.text();
        fetchedKeywords = parseKeywordsFromHtml(htmlText);
    } catch (e) {
        console.error('Error fetching web keywords:', e);
        throw new Error(`Error fetching web keywords (CORS or Network): ${e.message}`);
    }
}

function parseKeywordsFromHtml(htmlBody) {
    const parser = new DOMParser();
    const doc = parser.parseFromString(htmlBody, 'text/html');
    const fetched = {};

    const h3Elements = doc.querySelectorAll('h3');

    h3Elements.forEach(h3 => {
        const categoryName = h3.textContent.trim();
        const keywords = [];
        let currentElement = h3.nextElementSibling;
        let foundUl = null;

        while (currentElement) {
            if (currentElement.tagName.toLowerCase() === 'ul') {
                foundUl = currentElement;
                break;
            }
            if (currentElement.tagName.toLowerCase() === 'h3') break;

            const ulInDescendants = currentElement.querySelector('ul');
            if (ulInDescendants) {
                foundUl = ulInDescendants;
                break;
            }
            currentElement = currentElement.nextElementSibling;
        }

        if (foundUl) {
            const liElements = foundUl.querySelectorAll('li');
            liElements.forEach(li => {
                let keywordText = li.textContent.trim().replace(/\(.*?\)/g, '').trim();
                keywordText = keywordText.replace(/^\d+\.\s*/, '').trim();
                keywordText = keywordText.replace(/^-+\s*/, '').trim();
                if (keywordText) keywords.push(keywordText);
            });
        }

        if (keywords.length > 0) {
            fetched[categoryName] = keywords;
        }
    });

    return fetched;
}

function getDisplayKeywords() {
    const merged = {};

    // Copy fetched keywords
    for (const [category, keywords] of Object.entries(fetchedKeywords)) {
        merged[category] = [...keywords];
    }

    // Merge user keywords
    for (const [category, keywords] of Object.entries(userKeywords)) {
        if (merged[category]) {
            const existingKeywords = merged[category];
            keywords.forEach(keyword => {
                if (!existingKeywords.includes(keyword)) {
                    existingKeywords.push(keyword);
                }
            });
        } else {
            merged[category] = [...keywords];
        }
    }
    return merged;
}

function render() {
    const displayKeywords = getDisplayKeywords();
    const categories = Object.keys(displayKeywords);

    // Update Dropdown
    const select = document.getElementById('category-select');
    // Save current selection if valid
    const currentSelection = select.value;
    select.innerHTML = '<option value="" disabled>Category</option>';

    categories.forEach(category => {
        const option = document.createElement('option');
        option.value = category;
        option.textContent = category;
        select.appendChild(option);
    });

    if (currentSelection && categories.includes(currentSelection)) {
        select.value = currentSelection;
        selectedCategory = currentSelection;
    } else if (categories.length > 0 && !selectedCategory) {
        select.value = categories[0];
        selectedCategory = categories[0];
    } else if (selectedCategory) {
        select.value = selectedCategory;
    }

    // Render List
    const listContainer = document.getElementById('keywords-list');
    listContainer.innerHTML = '';

    categories.forEach(category => {
        const keywords = displayKeywords[category];

        const card = document.createElement('div');
        card.className = 'category-card';

        const header = document.createElement('div');
        header.className = 'category-header';

        const titleText = document.createElement('span');
        titleText.textContent = category;

        const icon = document.createElement('span');
        icon.className = 'toggle-icon';
        icon.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24"><path d="M0 0h24v24H0z" fill="none"/><path d="M16.59 8.59L12 13.17 7.41 8.59 6 10l6 6 6-6z"/></svg>'; // Down arrow

        header.appendChild(titleText);
        header.appendChild(icon);

        header.onclick = () => {
            const content = card.querySelector('.category-content');
            const iconSvg = header.querySelector('.toggle-icon');

            content.classList.toggle('hidden');
            iconSvg.classList.toggle('rotated');
        };

        const content = document.createElement('div');
        content.className = 'category-content hidden';

        keywords.forEach(keyword => {
            const chip = document.createElement('div');
            chip.className = 'keyword-chip';

            const textSpan = document.createElement('span');
            textSpan.textContent = keyword;
            chip.appendChild(textSpan);

            chip.onclick = () => {
                copyToClipboard(keyword);
                // Visual feedback
                document.querySelectorAll('.keyword-chip').forEach(c => c.classList.remove('selected'));
                chip.classList.add('selected');
            };

            // Check if it's a user keyword to show remove button
            if (userKeywords[category] && userKeywords[category].includes(keyword)) {
                const removeBtn = document.createElement('span');
                removeBtn.className = 'remove-btn';
                removeBtn.innerHTML = '&times;';
                removeBtn.title = 'Remove keyword';
                removeBtn.onclick = (e) => {
                    e.stopPropagation();
                    removeKeyword(category, keyword);
                };
                chip.appendChild(removeBtn);
            }

            content.appendChild(chip);
        });

        card.appendChild(header);
        card.appendChild(content);
        listContainer.appendChild(card);
    });
}

function addKeyword() {
    const input = document.getElementById('keyword-input');
    const text = input.value.trim();

    if (text && selectedCategory) {
        if (!userKeywords[selectedCategory]) {
            userKeywords[selectedCategory] = [];
        }

        if (!userKeywords[selectedCategory].includes(text)) {
            userKeywords[selectedCategory].push(text);
            render();
            saveKeywordsToKV(); // Auto save or wait for button? Dart app saves on add.
        }
        input.value = '';
    } else {
        if (!selectedCategory) alert('Please select a category first.');
    }
}

function removeKeyword(category, keyword) {
    if (userKeywords[category]) {
        userKeywords[category] = userKeywords[category].filter(k => k !== keyword);
        if (userKeywords[category].length === 0) {
            delete userKeywords[category];
        }
        render();
        saveKeywordsToKV();
    }
}

async function saveKeywordsToKV() {
    try {
        const response = await fetch(WORKER_SAVE_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(userKeywords)
        });

        if (response.ok) {
            showToast('Keywords saved successfully!');
        } else {
            throw new Error(`Server responded with ${response.status}`);
        }
    } catch (e) {
        alert(`Error saving keywords: ${e.message}`);
    }
}

function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(() => {
        showToast('Copied to clipboard');
    });
}

function showToast(message) {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.classList.add('show');
    setTimeout(() => {
        toast.classList.remove('show');
    }, 2000);
}

function showLoading(isLoading) {
    const indicator = document.getElementById('loading-indicator');
    if (isLoading) indicator.classList.remove('hidden');
    else indicator.classList.add('hidden');
}

function showError(msg) {
    const el = document.getElementById('error-message');
    el.textContent = msg;
    el.classList.remove('hidden');
}

function updateRawJsonDisplay() {
    document.getElementById('raw-json-display').textContent = rawJsonResponse;
}
