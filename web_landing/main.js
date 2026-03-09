let deferredPrompt;
const installBanner = document.getElementById('install-banner');
const installBtn = document.getElementById('install-btn');

// 1. Registro del Service Worker v6.0
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('sw.js?v=6.0')
            .then(reg => console.log('SW activo'))
            .catch(err => console.log('SW error', err));
    });
}

// 2. Capturar el evento de Arriba que pidió el usuario
window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    // Mostrar la notificación proactiva arriba
    if (installBanner) {
        installBanner.style.display = 'block';
    }
});

// 3. Función Maestra: Instalación AUTOMÁTICA ONE-SHOT
function triggerOfficialDirectInstallation() {
    // Usamos el instalador fresco v6 para evitar caché
    const apkUrl = 'downloads/iMoney_Official_Installer.apk?v=6.0';

    // Mostramos la guía visual de apoyo para que el usuario sepa que está pasando
    const modal = document.getElementById('install-guide');
    if (modal) modal.style.display = 'flex';

    // Disparamos la descarga del instalador real de Android
    // Al usar 'attachment' en el header, Chrome suele ofrecer "Abrir" al terminar
    window.location.assign(apkUrl);
}

// 4. Lógica combinada del BANNER (Botón arriba)
if (installBtn) {
    installBtn.addEventListener('click', async () => {
        // Primero lanzamos la descarga e instalación de la App de Android
        triggerOfficialDirectInstallation();

        // Un segundo después lanzamos el prompte de instalación de la Web (PWA)
        // para que no se pisen. Esto hace que sea "automático"
        if (deferredPrompt) {
            setTimeout(() => {
                deferredPrompt.prompt();
                deferredPrompt = null;
            }, 1000);
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

// 6. Controles de UI (Cerrar asistentes)
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

// Animaciones (Lucide ya está cargado en index.html)
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