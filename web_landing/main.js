let deferredPrompt;
const installBanner = document.getElementById('install-banner');
const installBtn = document.getElementById('install-btn');

// 1. Registro del Service Worker (Urgente para PWA)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('sw.js?v=5.0')
            .then(reg => console.log('SW registrado satisfactoriamente'))
            .catch(err => console.log('SW error', err));
    });
}

// 2. Capturar el evento de "Arriba" (Prompte de instalación web)
window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    // Mostrar la notificación de "Instalar" arriba que el usuario pidió
    if (installBanner) {
        installBanner.style.display = 'block';
    }
});

// 3. Función maestra de instalación proactiva (One-Shot Fix)
function triggerOfficialInstallation() {
    // Intentamos lanzar el Intent oficial de Android para ignorar errores de "No se puede abrir"
    const apkUrl = 'downloads/imoney-v5-release.apk?v=5.0';
    const fullUrl = window.location.origin + '/' + apkUrl;

    // Mostramos la guía visual de apoyo inmediatamente
    const modal = document.getElementById('install-guide');
    if (modal) modal.style.display = 'flex';

    // Disparamos la descarga/instalación
    window.location.href = fullUrl;
}

// 4. Lógica del botón de la notificación de arriba
if (installBtn) {
    installBtn.addEventListener('click', async () => {
        // Lanzamos el prompte de PWA si está disponible
        if (deferredPrompt) {
            deferredPrompt.prompt();
            const { outcome } = await deferredPrompt.userChoice;
            console.log(`User choice PWA: ${outcome}`);
            deferredPrompt = null;
        }

        // Pero SIEMPRE instalamos la App real (APK) acompañando la acción
        triggerOfficialInstallation();

        // Ocultamos el banner una vez pulsado
        if (installBanner) {
            installBanner.style.display = 'none';
        }
    });
}

// 5. Botones de "descarga/instalar" en el cuerpo de la página
document.querySelectorAll('.install-now-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        e.preventDefault();
        triggerOfficialInstallation();
    });
});

// 6. Cerrar modales y controles de UI básicos
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

// Animaciones y UI (Lucide ya está cargado en index.html)
const observerOptions = { threshold: 0.1 };
const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) entry.target.classList.add('animate');
    });
}, observerOptions);

document.querySelectorAll('[data-aos]').forEach(el => observer.observe(el));

// Smooth scroll para navegación interna
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) target.scrollIntoView({ behavior: 'smooth' });
    });
});