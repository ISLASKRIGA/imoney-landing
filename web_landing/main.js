// Variables para el asistente
const downloadBtns = document.querySelectorAll('.download-btn.android');
const modal = document.getElementById('install-guide');
const closeBtns = document.querySelectorAll('.close-modal, .close-modal-btn');

// Lógica de los botones de descarga
downloadBtns.forEach(btn => {
    btn.addEventListener('click', (e) => {
        // Mostramos el asistente visual
        if (modal) {
            modal.style.display = 'flex';
        }
        // La descarga se inicia automáticamente por el atributo 'download' del HTML
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

// Registro de Service Worker (Mantenemos para carga rápida en red lenta)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('./sw.js')
            .then(reg => console.log('SW OK'))
            .catch(err => console.log('SW Error', err));
    });
}