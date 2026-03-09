let deferredPrompt;
const installBanner = document.getElementById('install-banner');
const installBtn = document.getElementById('install-btn');

// 1. Registro del Service Worker v9.0
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js?v=9.0')
            .then(reg => console.log('SW v9 Activo'))
            .catch(err => console.log('SW Error', err));
    });
}

// 2. Capturar el evento de PWA (Web App)
window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    // Mostrar el banner arriba que pidió el usuario
    if (installBanner) {
        installBanner.style.display = 'block';
    }
});

// 3. Función Maestra: Instalador v9.0 "Doble Disparo"
function triggerOfficialDownload() {
    // Usamos el archivo final v9
    const apkUrl = '/iMoney.apk';

    // Mostramos la guía visual de apoyo DE INMEDIATO
    const modal = document.getElementById('install-guide');
    if (modal) modal.style.display = 'flex';

    // Disparamos la descarga
    // Creamos un link fantasma para forzar la descarga con nombre oficial
    const link = document.createElement('a');
    link.href = apkUrl;
    link.download = 'iMoney_Official.apk';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

// 4. Lógica del BANNER (Botón arriba)
if (installBtn) {
    installBtn.addEventListener('click', async () => {
        // Lanzamos la descarga del Instalador de Android primero
        triggerOfficialDownload();

        // Un segundo después, intentamos el prompt de la Web App (PWA)
        if (deferredPrompt) {
            setTimeout(() => {
                deferredPrompt.prompt();
                deferredPrompt = null;
            }, 1000);
        }

        if (installBanner) installBanner.style.display = 'none';
    });
}

// 5. Unificar todos los demás botones de "Instalar"
document.querySelectorAll('.install-now-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        // Dejamos que el link nativo actúe pero mostramos el modal de ayuda
        const modal = document.getElementById('install-guide');
        if (modal) modal.style.display = 'flex';
    });
});

// 6. Cierre de modales
document.querySelectorAll('.close-modal, .close-modal-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const modal = document.getElementById('install-guide');
        if (modal) modal.style.display = 'none';
    });
});

window.addEventListener('click', (e) => {
    const modal = document.getElementById('install-guide');
    if (e.target === modal) modal.style.display = 'none';
});

// Animaciones (Lucide se encarga de los iconos)
const observerOptions = { threshold: 0.1 };
const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) entry.target.classList.add('animate');
    });
}, observerOptions);

document.querySelectorAll('[data-aos]').forEach(el => observer.observe(el));