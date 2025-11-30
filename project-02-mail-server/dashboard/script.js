/**
 * Mail Server Dashboard - Auto-refresh and Interactivity
 *
 * Purpose:
 *   Provides automatic page refresh, manual refresh control, and
 *   client-side interactivity for the mail server dashboard.
 *
 * Skills Demonstrated:
 *   - ES6+ JavaScript
 *   - setInterval for periodic updates
 *   - localStorage for persistence
 *   - DOM manipulation
 *   - Event handling
 *
 * Author: Linux Sysadmin Portfolio
 * License: MIT
 */

// Configuration
const CONFIG = {
    refreshInterval: 10000, // 10 seconds
    storageKey: 'mailDashboardAutoRefresh',
};

// State management
let autoRefreshEnabled = true;
let refreshTimer = null;

/**
 * Initialize dashboard on page load
 */
function init() {
    // Restore auto-refresh preference from localStorage
    const savedPref = localStorage.getItem(CONFIG.storageKey);
    if (savedPref !== null) {
        autoRefreshEnabled = savedPref === 'true';
    }

    // Update UI
    updateAutoRefreshDisplay();

    // Start auto-refresh if enabled
    if (autoRefreshEnabled) {
        startAutoRefresh();
    }

    // Add keyboard shortcuts
    document.addEventListener('keydown', handleKeyboard);

    // Add visual feedback for loading
    addLoadingIndicator();

    console.log('Mail Server Dashboard initialized');
}

/**
 * Start automatic page refresh
 */
function startAutoRefresh() {
    if (refreshTimer) {
        clearInterval(refreshTimer);
    }

    refreshTimer = setInterval(() => {
        console.log('Auto-refreshing dashboard...');
        refreshPage();
    }, CONFIG.refreshInterval);

    console.log(`Auto-refresh started (interval: ${CONFIG.refreshInterval}ms)`);
}

/**
 * Stop automatic page refresh
 */
function stopAutoRefresh() {
    if (refreshTimer) {
        clearInterval(refreshTimer);
        refreshTimer = null;
    }
    console.log('Auto-refresh stopped');
}

/**
 * Toggle auto-refresh on/off
 */
function toggleAutoRefresh() {
    autoRefreshEnabled = !autoRefreshEnabled;

    // Save preference
    localStorage.setItem(CONFIG.storageKey, autoRefreshEnabled.toString());

    // Update UI
    updateAutoRefreshDisplay();

    // Start/stop refresh
    if (autoRefreshEnabled) {
        startAutoRefresh();
        showNotification('Auto-refresh enabled', 'success');
    } else {
        stopAutoRefresh();
        showNotification('Auto-refresh disabled', 'info');
    }
}

/**
 * Update auto-refresh display in header
 */
function updateAutoRefreshDisplay() {
    const element = document.getElementById('auto-refresh');
    if (element) {
        const status = autoRefreshEnabled ? 'ON' : 'OFF';
        const color = autoRefreshEnabled ? '#48bb78' : '#f56565';
        element.innerHTML = `Auto-refresh: <strong style="color: ${color}">${status}</strong>`;
    }
}

/**
 * Refresh the page with smooth transition
 */
function refreshPage() {
    // Add loading class to body
    document.body.classList.add('loading');

    // Reload after short delay for visual feedback
    setTimeout(() => {
        window.location.reload();
    }, 200);
}

/**
 * Manual refresh trigger
 */
function manualRefresh() {
    showNotification('Refreshing dashboard...', 'info');
    refreshPage();
}

/**
 * Show temporary notification
 */
function showNotification(message, type = 'info') {
    // Remove existing notifications
    const existing = document.querySelector('.notification');
    if (existing) {
        existing.remove();
    }

    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.textContent = message;

    // Style notification
    Object.assign(notification.style, {
        position: 'fixed',
        top: '20px',
        right: '20px',
        padding: '1rem 1.5rem',
        borderRadius: '8px',
        backgroundColor: type === 'success' ? '#48bb78' : type === 'info' ? '#667eea' : '#f56565',
        color: 'white',
        fontWeight: '600',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.3)',
        zIndex: '9999',
        animation: 'slideIn 0.3s ease-out',
    });

    // Add to page
    document.body.appendChild(notification);

    // Auto-remove after 3 seconds
    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease-out';
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

/**
 * Add loading indicator styles
 */
function addLoadingIndicator() {
    const style = document.createElement('style');
    style.textContent = `
        @keyframes slideIn {
            from {
                transform: translateX(100%);
                opacity: 0;
            }
            to {
                transform: translateX(0);
                opacity: 1;
            }
        }

        @keyframes slideOut {
            from {
                transform: translateX(0);
                opacity: 1;
            }
            to {
                transform: translateX(100%);
                opacity: 0;
            }
        }

        .loading::before {
            content: '';
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 3px;
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            z-index: 9999;
            animation: loadingBar 0.5s ease-in-out;
        }

        @keyframes loadingBar {
            0% {
                transform: scaleX(0);
                transform-origin: left;
            }
            100% {
                transform: scaleX(1);
                transform-origin: left;
            }
        }
    `;
    document.head.appendChild(style);
}

/**
 * Handle keyboard shortcuts
 */
function handleKeyboard(event) {
    // R key - Manual refresh
    if (event.key === 'r' || event.key === 'R') {
        if (!event.ctrlKey && !event.metaKey) {
            event.preventDefault();
            manualRefresh();
        }
    }

    // T key - Toggle auto-refresh
    if (event.key === 't' || event.key === 'T') {
        event.preventDefault();
        toggleAutoRefresh();
    }

    // ? key - Show help
    if (event.key === '?') {
        event.preventDefault();
        showHelp();
    }
}

/**
 * Show keyboard shortcuts help
 */
function showHelp() {
    const helpText = `
Keyboard Shortcuts:
  R - Manual refresh
  T - Toggle auto-refresh
  ? - Show this help
    `;
    alert(helpText.trim());
}

/**
 * Add countdown timer to header
 */
function addCountdownTimer() {
    const headerInfo = document.querySelector('.header-info');
    if (headerInfo && autoRefreshEnabled) {
        const timerElement = document.createElement('span');
        timerElement.id = 'refresh-countdown';
        headerInfo.appendChild(timerElement);

        let secondsLeft = CONFIG.refreshInterval / 1000;

        const countdownInterval = setInterval(() => {
            secondsLeft--;
            if (timerElement) {
                timerElement.textContent = `Next refresh: ${secondsLeft}s`;
            }

            if (secondsLeft <= 0) {
                clearInterval(countdownInterval);
            }
        }, 1000);
    }
}

/**
 * Highlight critical values
 */
function highlightCriticalValues() {
    // Highlight high queue numbers
    const statValues = document.querySelectorAll('.stat-value');
    statValues.forEach(element => {
        const value = parseInt(element.textContent);
        if (value > 100) {
            element.style.color = '#f56565';
            element.style.animation = 'pulse 2s ease-in-out infinite';
        }
    });

    // Highlight mailboxes near quota
    const progressBars = document.querySelectorAll('.progress-fill');
    progressBars.forEach(bar => {
        const width = parseInt(bar.style.width);
        if (width > 90) {
            bar.parentElement.style.boxShadow = '0 0 10px rgba(245, 101, 101, 0.5)';
        }
    });
}

// Initialize on DOM ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}

// Highlight critical values after page load
window.addEventListener('load', () => {
    highlightCriticalValues();
    // addCountdownTimer(); // Optional: uncomment to show countdown
});

// Export functions for global access
window.toggleAutoRefresh = toggleAutoRefresh;
window.manualRefresh = manualRefresh;
