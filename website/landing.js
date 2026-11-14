// Landing Page JavaScript
document.addEventListener('DOMContentLoaded', function() {
    

    // Initialize animations
    initializeAnimations();
    
    // Initialize smooth scrolling
    initializeSmoothScrolling();
    
    // Initialize header effects
    initializeHeaderEffects();
    
    // Initialize interactive elements
    initializeInteractiveElements();
});

// Initialize scroll animations
function initializeAnimations() {
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('animate-active');
            }
        });
    }, observerOptions);

    // Add animation classes to specific sections FIRST, then observe them.
    // (The old order observed before the class was added, so every section stayed invisible.)
    const sections = document.querySelectorAll('section');
    sections.forEach((section, index) => {
        section.classList.add('animate-on-scroll');
        section.style.setProperty('--stagger-delay', `${index * 0.2}s`);
    });

    document.querySelectorAll('.animate-on-scroll').forEach(el => {
        observer.observe(el);
    });
}

// Initialize smooth scrolling for navigation links
function initializeSmoothScrolling() {
    const navLinks = document.querySelectorAll('a[href^="#"]');
    
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href');
            const targetElement = document.querySelector(targetId);
            
            if (targetElement) {
                const headerHeight = document.querySelector('.header').offsetHeight;
                const targetPosition = targetElement.offsetTop - headerHeight;
                
                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });
}

// Initialize header effects
function initializeHeaderEffects() {
    const header = document.querySelector('.header');
    let lastScrollY = window.scrollY;
    
    window.addEventListener('scroll', () => {
        const currentScrollY = window.scrollY;
        
        // Add/remove scrolled class for styling
        if (currentScrollY > 50) {
            header.classList.add('scrolled');
        } else {
            header.classList.remove('scrolled');
        }
        
        // Hide/show header on scroll
        if (currentScrollY > lastScrollY && currentScrollY > 100) {
            header.style.transform = 'translateY(-100%)';
        } else {
            header.style.transform = 'translateY(0)';
        }
        
        lastScrollY = currentScrollY;
    });
}

// Initialize interactive elements
function initializeInteractiveElements() {
    // Add hover effects to feature cards
    const featureCards = document.querySelectorAll('.feature-card');
    featureCards.forEach(card => {
        card.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-8px) scale(1.02)';
        });
        
        card.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0) scale(1)';
        });
    });
    
    // Add click effects to buttons
    const buttons = document.querySelectorAll('.btn');
    buttons.forEach(button => {
        button.addEventListener('click', function(e) {
            // Create ripple effect
            const ripple = document.createElement('span');
            const rect = this.getBoundingClientRect();
            const size = Math.max(rect.width, rect.height);
            const x = e.clientX - rect.left - size / 2;
            const y = e.clientY - rect.top - size / 2;
            
            ripple.style.width = ripple.style.height = size + 'px';
            ripple.style.left = x + 'px';
            ripple.style.top = y + 'px';
            ripple.classList.add('ripple');
            
            this.appendChild(ripple);
            
            setTimeout(() => {
                ripple.remove();
            }, 600);
        });
    });
    
    // Add parallax effect to hero section
    const hero = document.querySelector('.hero');
    if (hero) {
        window.addEventListener('scroll', () => {
            const scrolled = window.pageYOffset;
            const rate = scrolled * -0.5;
            hero.style.transform = `translateY(${rate}px)`;
        });
    }
}

// Add CSS for ripple effect
const style = document.createElement('style');
style.textContent = `
    .btn {
        position: relative;
        overflow: hidden;
    }
    
    .ripple {
        position: absolute;
        border-radius: 50%;
        background: rgba(255, 255, 255, 0.3);
        transform: scale(0);
        animation: ripple-animation 0.6s linear;
        pointer-events: none;
    }
    
    @keyframes ripple-animation {
        to {
            transform: scale(4);
            opacity: 0;
        }
    }
    
    .header {
        transition: transform 0.3s ease, background-color 0.3s ease;
    }
    
    .header.scrolled {
        background: rgba(74, 144, 226, 0.95);
        backdrop-filter: blur(20px);
    }
    
    .feature-card {
        transition: transform 0.3s ease, box-shadow 0.3s ease;
    }
    
    .download-btn {
        transition: transform 0.3s ease, box-shadow 0.3s ease;
    }
    
    .download-btn:hover {
        transform: translateY(-4px);
        box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
    }
    
    .trial-card {
        transition: transform 0.3s ease, box-shadow 0.3s ease;
    }
    
    .trial-card:hover {
        transform: translateY(-4px);
        box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
    }
    
    .mockup-screen {
        transition: transform 0.3s ease;
    }
    
    .mockup-screen:hover {
        transform: scale(1.05);
    }
    
    .phone-screen {
        transition: transform 0.3s ease;
    }
    
    .phone-screen:hover {
        transform: scale(1.1);
    }
    
    /* Loading animation for buttons */
    .btn.loading {
        position: relative;
        color: transparent;
    }
    
    .btn.loading::after {
        content: '';
        position: absolute;
        width: 20px;
        height: 20px;
        top: 50%;
        left: 50%;
        margin-left: -10px;
        margin-top: -10px;
        border: 2px solid transparent;
        border-top: 2px solid currentColor;
        border-radius: 50%;
        animation: spin 1s linear infinite;
    }
    
    @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
    }
    
    /* Floating animation for mockups */
    .app-mockup, .trial-mockup, .phone-mockup {
        animation: float 6s ease-in-out infinite;
    }
    
    @keyframes float {
        0%, 100% { transform: translateY(0px); }
        50% { transform: translateY(-10px); }
    }
    
    /* Gradient animation for hero background */
    .hero {
        background-size: 400% 400%;
        animation: gradientShift 15s ease infinite;
    }
    
    @keyframes gradientShift {
        0% { background-position: 0% 50%; }
        50% { background-position: 100% 50%; }
        100% { background-position: 0% 50%; }
    }
    
    /* Typing animation for hero title */
    .hero-title {
        overflow: hidden;
        border-right: 2px solid var(--primary);
        white-space: nowrap;
        animation: typing 3.5s steps(40, end), blink-caret 0.75s step-end infinite;
    }
    
    @keyframes typing {
        from { width: 0; }
        to { width: 100%; }
    }
    
    @keyframes blink-caret {
        from, to { border-color: transparent; }
        50% { border-color: var(--primary); }
    }
`;

document.head.appendChild(style);

// Add loading states to buttons
function addLoadingState(button) {
    button.classList.add('loading');
    button.disabled = true;
}

function removeLoadingState(button) {
    button.classList.remove('loading');
    button.disabled = false;
}

// Handle trial button click
document.addEventListener('click', function(e) {
    if (e.target.closest('.btn-primary') && e.target.closest('.btn-primary').textContent.includes('Start Free Trial')) {
        const button = e.target.closest('.btn-primary');
        addLoadingState(button);
        
        // Simulate loading
        setTimeout(() => {
            removeLoadingState(button);
            window.location.href = 'index.html';
        }, 1000);
    }
});

// Add scroll progress indicator
function addScrollProgress() {
    const progressBar = document.createElement('div');
    progressBar.className = 'scroll-progress';
    progressBar.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 0%;
        height: 3px;
        background: var(--banana-gradient);
        z-index: 1001;
        transition: width 0.1s ease;
    `;
    
    document.body.appendChild(progressBar);
    
    window.addEventListener('scroll', () => {
        const scrollTop = window.pageYOffset;
        const docHeight = document.body.offsetHeight - window.innerHeight;
        const scrollPercent = (scrollTop / docHeight) * 100;
        progressBar.style.width = scrollPercent + '%';
    });
}

// Initialize scroll progress
addScrollProgress();

// Add mobile menu functionality
function initializeMobileMenu() {
    const header = document.querySelector('.header');
    const nav = document.querySelector('.nav');
    
    // Create mobile menu button
    const mobileMenuBtn = document.createElement('button');
    mobileMenuBtn.className = 'mobile-menu-btn';
    mobileMenuBtn.innerHTML = '<i class="fas fa-bars"></i>';
    mobileMenuBtn.style.cssText = `
        display: none;
        background: none;
        border: none;
        color: var(--foreground);
        font-size: 1.5rem;
        cursor: pointer;
        padding: 0.5rem;
    `;
    
    header.querySelector('.header-content').appendChild(mobileMenuBtn);
    
    // Add mobile menu styles
    const mobileStyles = document.createElement('style');
    mobileStyles.textContent = `
        @media (max-width: 768px) {
            .mobile-menu-btn {
                display: block !important;
            }
            
            .nav {
                position: absolute;
                top: 100%;
                left: 0;
                right: 0;
                background: var(--blue-banana-gradient);
                flex-direction: column;
                padding: 1rem;
                transform: translateY(-100%);
                opacity: 0;
                visibility: hidden;
                transition: all 0.3s ease;
                box-shadow: var(--shadow-lg);
            }
            
            .nav.active {
                transform: translateY(0);
                opacity: 1;
                visibility: visible;
            }
            
            .nav-link {
                padding: 0.75rem 1rem;
                width: 100%;
                text-align: center;
                border-radius: var(--radius-md);
            }
        }
    `;
    
    document.head.appendChild(mobileStyles);
    
    // Toggle mobile menu
    mobileMenuBtn.addEventListener('click', () => {
        nav.classList.toggle('active');
        mobileMenuBtn.innerHTML = nav.classList.contains('active') ? 
            '<i class="fas fa-times"></i>' : '<i class="fas fa-bars"></i>';
    });
    
    // Close mobile menu when clicking outside
    document.addEventListener('click', (e) => {
        if (!header.contains(e.target)) {
            nav.classList.remove('active');
            mobileMenuBtn.innerHTML = '<i class="fas fa-bars"></i>';
        }
    });
}

// Initialize mobile menu
initializeMobileMenu();

// Add analytics tracking
function trackEvent(eventName, properties = {}) {
    // Simulate analytics tracking
    console.log('Analytics Event:', eventName, properties);
    
    // You can integrate with Google Analytics, Mixpanel, etc.
    if (typeof gtag !== 'undefined') {
        gtag('event', eventName, properties);
    }
}

// Track button clicks
document.addEventListener('click', function(e) {
    if (e.target.closest('.btn')) {
        const button = e.target.closest('.btn');
        const buttonText = button.textContent.trim();
        
        trackEvent('button_click', {
            button_text: buttonText,
            button_type: button.classList.contains('btn-primary') ? 'primary' : 'secondary',
            page: 'landing'
        });
    }
});

// Track scroll depth
let maxScrollDepth = 0;
window.addEventListener('scroll', () => {
    const scrollPercent = Math.round((window.pageYOffset / (document.body.offsetHeight - window.innerHeight)) * 100);
    
    if (scrollPercent > maxScrollDepth) {
        maxScrollDepth = scrollPercent;
        
        // Track scroll milestones
        if (maxScrollDepth >= 25 && maxScrollDepth < 50) {
            trackEvent('scroll_25_percent');
        } else if (maxScrollDepth >= 50 && maxScrollDepth < 75) {
            trackEvent('scroll_50_percent');
        } else if (maxScrollDepth >= 75 && maxScrollDepth < 100) {
            trackEvent('scroll_75_percent');
        } else if (maxScrollDepth >= 100) {
            trackEvent('scroll_100_percent');
        }
    }
});

console.log('Landing page JavaScript initialized successfully');
