// Función de experto para forzar la instalación
function forceInstall(url) {
    // Si estamos en un navegador que soporta la redirección directa al instalador
    window.location.assign(url);

    // Mostramos el modal de ayuda con un botón de reintento directo
    const modal = document.getElementById('install-guide');
    if (modal) modal.style.display = 'flex';
}

// Variables para el asistente
const downloadBtns = document.querySelectorAll('.download-btn.android');
const modal = document.getElementById('install-guide');
const closeBtns = document.querySelectorAll('.close-modal, .close-modal-btn');

// Lógica de los botones de descarga
downloadBtns.forEach(btn => {
    btn.addEventListener('click', (e) => {
        // En lugar de e.preventDefault(), dejamos que el navegador inicie la descarga
        // Pero activamos el UI de ayuda inmediatamente
        if (modal) {
            modal.style.display = 'flex';
        }
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