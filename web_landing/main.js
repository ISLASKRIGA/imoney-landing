// Variables para el asistente
const downloadBtns = document.querySelectorAll('.download-btn.android');
const modal = document.getElementById('install-guide');
const closeBtns = document.querySelectorAll('.close-modal, .close-modal-btn');

// Lógica de los botones de descarga
downloadBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        // Mostramos el asistente visual para la App de Flutter
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

// Navbar shadow on scroll
window.addEventListener('scroll', () => {
    const navbar = document.querySelector('.navbar');
    if (window.scrollY > 50) {
        navbar.style.boxShadow = '0 10px 30px rgba(0,0,0,0.5)';
    } else {
        navbar.style.boxShadow = 'none';
    }
});