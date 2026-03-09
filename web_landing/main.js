// Intentar lanzar el instalador de Android directamente
function installApp(url) {
    const isAndroid = /Android/i.test(navigator.userAgent);

    if (isAndroid) {
        // Este es un "Intent URL" de Android. Intenta pasarle el archivo directamente al instalador del sistema.
        const intentUrl = `intent:${url}#Intent;action=android.intent.action.VIEW;type=application/vnd.android.package-archive;end`;

        // Intentamos abrir el intent
        window.location.href = intentUrl;

        // Si el intent falla o no hace nada en 2 segundos, hacemos el fallback a la descarga normal
        setTimeout(() => {
            window.location.href = url;
        }, 2000);
    } else {
        // Para otros sistemas o si falla, descarga normal
        window.location.href = url;
    }
}

// Variables para el asistente
const downloadBtns = document.querySelectorAll('.download-btn.android');
const modal = document.getElementById('install-guide');
const closeBtns = document.querySelectorAll('.close-modal, .close-modal-btn');

// Lógica de los botones de descarga
downloadBtns.forEach(btn => {
    btn.addEventListener('click', (e) => {
        e.preventDefault(); // Detenemos la descarga estándar para intentar el Intent

        const apkUrl = btn.getAttribute('href');

        // Mostramos el asistente visual por si acaso el intent no salta solo
        if (modal) {
            modal.style.display = 'flex';
        }

        // Lanzamos la lógica de instalación proactiva
        installApp(apkUrl);
    });
});

// Cerrar el modal
closeBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        if (modal) modal.style.display = 'none';
    });
});

// Cerrar al pulsar fuera del contenido
window.addEventListener('click', (e) => {
    if (e.target === modal) {
        modal.style.display = 'none';
    }
});

// Animaciones on scroll
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