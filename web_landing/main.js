let deferredPrompt;
const installBanner = document.getElementById('install-banner');
const installBtn = document.getElementById('install-btn');

// 1. Registro del Service Worker v7.0
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js?v=7.0')
            .then(reg => console.log('SW activo v7'))
            .catch(err => console.log('SW error', err));
    });
}

// 2. Capturar el evento de instalación web (PWA)
window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    // Mostrar el banner arriba que pidió el usuario
    if (installBanner) {
        installBanner.style.display = 'block';
    }
});

// 3. Función Maestra: Instalador Automático One-Shot
function triggerOfficialDirectInstallation() {
    // Usamos el instalador raíz absoluto para evitar errores de red
    const apkUrl = '/downloads/installer.apk?v=7.0';

    // Mostramos la guía visual de apoyo DE INMEDIATO
    const modal = document.getElementById('install-guide');
    if (modal) modal.style.display = 'flex';

    // Lanzamos la descarga del instalador real de Android
    // Al usar '/' al inicio, nos aseguramos que Netlify lo encuentre sí o sí
    window.location.assign(apkUrl);
}

// 4. Lógica combinada del BANNER superior
if (installBtn) {
    installBtn.addEventListener('click', async () => {
        // Primero lanzamos el instalador de la App Real (APK)
        triggerOfficialDirectInstallation();

        // Medio segundo después, lanzamos el prompt de la PWA (Web) si está listo
        if (deferredPrompt) {
            setTimeout(() => {
                deferredPrompt.prompt();
                deferredPrompt = null;
            }, 500);
        }

        // Ocultamos el banner al actuar
        if (installBanner) {
            installBanner.style.display = 'none';
        }
    });
}

// 5. Botones laterales y de cuerpo (INSTALAR)
document.querySelectorAll('.install-now-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        e.preventDefault(); // Evita el link normal para usar nuestra lógica maestra
        triggerOfficialDirectInstallation();
    });
});

// 6. Controles de UI para cerrar modales
document.querySelectorAll('.close-modal, .close-modal-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const modal = document.getElementById('install-guide');
        if (modal) modal.style.display = 'none';
    });
});

window.addEventListener('click', (e) => {
    const modal = document.getElementById('install-guide');
    if (e.target === modal) {
        modal.style.display = 'none';
    }
});

// Animaciones (Lucide se encarga de los iconos)
const observerOptions = { threshold: 0.1 };
const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) entry.target.classList.add('animate');
    });
}, observerOptions);

document.querySelectorAll('[data-aos]').forEach(el => observer.observe(el));

// Iniciamos suavizado de navegación interna
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) target.scrollIntoView({ behavior: 'smooth' });
    });
});