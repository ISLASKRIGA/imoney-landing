let deferredPrompt;
const installBanner = document.getElementById('install-banner');
const installBtn = document.getElementById('install-btn');

// 1. Registro del Service Worker v8.0 (Limpieza de caché profunda)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js?v=8.0')
            .then(reg => {
                console.log('SW activo v8');
                // Forzamos actualización inmediata si hay una nueva versión
                reg.update();
            })
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

// 3. Función Maestra: Instalador Automático One-Shot Definitivo
function triggerOfficialDirectInstallation() {
    // Usamos el archivo en la raíz para evitar fallos de ruta o CDN cache
    const apkUrl = '/installer.apk';

    // Mostramos la guía visual de apoyo DE INMEDIATO
    const modal = document.getElementById('install-guide');
    if (modal) modal.style.display = 'flex';

    // Lanzamos la descarga del instalador real de Android
    // Sin parámetros basura (?v=X) para que Chrome lo trate como una descarga pura
    window.location.assign(apkUrl);
}

// 4. Lógica combinada del BANNER superior (INSTALAR APP)
if (installBtn) {
    installBtn.addEventListener('click', async () => {
        // Lanzamos la descarga de la APK Real
        triggerOfficialDirectInstallation();

        // Esperamos medio segundo para no saturar procesos y lanzamos el prompt de la Web (PWA)
        if (deferredPrompt) {
            setTimeout(() => {
                deferredPrompt.prompt();
                deferredPrompt = null;
            }, 600);
        }

        // Ocultamos el banner
        if (installBanner) {
            installBanner.style.display = 'none';
        }
    });
}

// 5. Botones laterales y de cuerpo (INSTALAR)
document.querySelectorAll('.install-now-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        e.preventDefault();
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

// Animaciones (Lucide ya está en index.html)
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