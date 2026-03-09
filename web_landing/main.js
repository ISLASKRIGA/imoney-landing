let deferredPrompt;
const installBanner = document.getElementById('install-banner');
const installBtn = document.getElementById('install-btn');

// Registro del Service Worker
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('sw.js?v=4.0')
            .then(reg => console.log('SW registrado'))
            .catch(err => console.log('SW error', err));
    });
}

// Lógica de captura del evento de instalación PWA
window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    // Mostrar el banner de instalación arriba
    if (installBanner) {
        installBanner.style.display = 'block';
    }
});

// Al pulsar el botón del banner (INSTALAR)
if (installBtn) {
    installBtn.addEventListener('click', async () => {
        if (deferredPrompt) {
            deferredPrompt.prompt();
            const { outcome } = await deferredPrompt.userChoice;
            console.log(`User choice: ${outcome}`);
            deferredPrompt = null;
        }

        // Acción combinada: También mostramos el asistente de APK por si acaso
        const modal = document.getElementById('install-guide');
        if (modal) modal.style.display = 'flex';

        // Y activamos la descarga del APK real para estar seguros
        window.location.href = 'downloads/iMoney.apk';
    });
}

// Botones de "INSTALAR" en el cuerpo de la página
document.querySelectorAll('.install-now-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        // Mostramos el asistente visual
        const modal = document.getElementById('install-guide');
        if (modal) modal.style.display = 'flex';

        // El link href="downloads/iMoney.apk" hará el resto
    });
});

// Cerrar modales y asistentes
document.querySelectorAll('.close-modal, .close-modal-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const modal = document.getElementById('install-guide');
        if (modal) modal.style.display = 'none';
    });
});

// Cerrar banner PWA
window.addEventListener('click', (e) => {
    const modal = document.getElementById('install-guide');
    if (e.target === modal) {
        modal.style.display = 'none';
    }
});

// Animaciones y UI
const observerOptions = { threshold: 0.1 };
const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) entry.target.classList.add('animate');
    });
}, observerOptions);

document.querySelectorAll('[data-aos]').forEach(el => observer.observe(el));

// Smooth scroll
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) target.scrollIntoView({ behavior: 'smooth' });
    });
});