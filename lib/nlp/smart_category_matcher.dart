// SmartCategoryMatcher — mapea texto libre a categorías del usuario.
//
// Funciona en tres capas:
//  1. Match exacto por nombre (case-insensitive).
//  2. Match por alias semánticos: diccionario de palabras → categoría canónica.
//  3. Match difuso (token overlap) como fallback.
//
// Recibe las categorías reales del usuario para operar sobre ellas.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/categories/category_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Alias semánticos globales: word → nombre canónico de categoría
// Una sola fuente de verdad. Las claves son palabras normalizadas (sin tildes).
// ─────────────────────────────────────────────────────────────────────────────
final Map<String, String> _semanticAliases = {
  // ── Comida / Restaurantes ──
  'comida': 'Comida', 'comer': 'Comida', 'almuerzo': 'Comida',
  'desayuno': 'Comida', 'cena': 'Comida', 'tacos': 'Comida',
  'tortas': 'Comida', 'torta': 'Comida', 'pizza': 'Comida',
  'hamburguesa': 'Comida', 'hamburgesa': 'Comida', 'sushi': 'Comida',
  'lonche': 'Comida', 'lunch': 'Comida', 'cafe': 'Comida',
  'coffee': 'Comida', 'starbucks': 'Comida', 'dominos': 'Comida',
  'mcdonalds': 'Comida', 'kfc': 'Comida', 'subway': 'Comida',
  'snack': 'Comida', 'merienda': 'Comida', 'antojitos': 'Comida',
  'gorditas': 'Comida', 'quesadillas': 'Comida', 'pollo': 'Comida',
  'sopa': 'Comida', 'caldo': 'Comida', 'elotes': 'Comida',
  'tamales': 'Comida', 'enchiladas': 'Comida', 'taqueria': 'Comida',
  'restaurante': 'Comida', 'wings': 'Comida', 'burrito': 'Comida',
  'tamal': 'Comida', 'pozole': 'Comida', 'carnitas': 'Comida',
  'barbacoa': 'Comida', 'milanesa': 'Comida', 'chilaquiles': 'Comida',
  'huaraches': 'Comida',

  // ── Mercado / Super ──
  'super': 'Super', 'supermercado': 'Super', 'mercado': 'Super',
  'despensa': 'Super', 'walmart': 'Super', 'soriana': 'Super',
  'chedraui': 'Super', 'costco': 'Super', 'oxxo': 'Super',
  'tienda': 'Super', 'abarrotes': 'Super', 'mandado': 'Super',
  'frijoles': 'Super', 'jitomate': 'Super', 'tomate': 'Super',
  'cebolla': 'Super', 'chile': 'Super', 'aguacate': 'Super',
  'naranja': 'Super', 'manzana': 'Super', 'platano': 'Super',
  'limon': 'Super', 'zanahoria': 'Super', 'papa': 'Super',
  'papas': 'Super', 'arroz': 'Super', 'atun': 'Super',
  'sardinas': 'Super', 'huevo': 'Super', 'huevos': 'Super',
  'aceite': 'Super', 'sal': 'Super', 'azucar': 'Super',
  'harina': 'Super', 'fideo': 'Super', 'pasta': 'Super',
  'leche': 'Super', 'pan': 'Super', 'tortillas': 'Super',
  'verduras': 'Super', 'frutas': 'Super', 'abarrote': 'Super',
  'champinon': 'Super', 'champiñon': 'Super', 'brocoli': 'Super',
  'espinaca': 'Super', 'pepino': 'Super', 'lechuga': 'Super',
  'pimienta': 'Super', 'detergente': 'Super', 'jabon': 'Super',
  'shampoo': 'Super', 'crema': 'Super', 'yogurt': 'Super',
  'queso': 'Super', 'jamon': 'Super', 'mantequilla': 'Super',
  'cereal': 'Super', 'galletas': 'Super', 'refresco': 'Super',
  'agua': 'Super', 'jugo': 'Super',

  // ── Transporte ──
  'uber': 'Transporte', 'didi': 'Transporte', 'taxi': 'Transporte',
  'cabify': 'Transporte', 'bus': 'Transporte', 'camion': 'Transporte',
  'metro': 'Transporte', 'metrobus': 'Transporte',
  'gasolina': 'Transporte', 'combustible': 'Transporte', 'pemex': 'Transporte',
  'caseta': 'Transporte', 'autopista': 'Transporte', 'peaje': 'Transporte',
  'estacionamiento': 'Transporte', 'parking': 'Transporte',
  'tenencia': 'Transporte', 'verificacion': 'Transporte',
  'afinacion': 'Transporte', 'llanta': 'Transporte', 'transporte': 'Transporte',
  'pasaje': 'Transporte', 'boleto': 'Transporte', 'pesero': 'Transporte',
  'colectivo': 'Transporte', 'autobus': 'Transporte', 'trolebus': 'Transporte',
  'moto': 'Transporte', 'bicicleta': 'Transporte', 'patinete': 'Transporte',

  // ── Ropa ──
  'ropa': 'Ropa', 'zapatos': 'Ropa', 'tenis': 'Ropa', 'zapatillas': 'Ropa',
  'camisa': 'Ropa', 'pantalon': 'Ropa', 'jeans': 'Ropa', 'vestido': 'Ropa',
  'falda': 'Ropa', 'blusa': 'Ropa', 'playera': 'Ropa', 'sudadera': 'Ropa',
  'chamarra': 'Ropa', 'jacket': 'Ropa', 'nike': 'Ropa', 'adidas': 'Ropa',
  'zara': 'Ropa', 'shein': 'Ropa', 'liverpool': 'Ropa', 'moda': 'Ropa',
  'outfit': 'Ropa', 'calcetines': 'Ropa', 'gorra': 'Ropa', 'sombrero': 'Ropa',
  'bolsa': 'Ropa', 'cartera': 'Ropa', 'cinturon': 'Ropa', 'abrigo': 'Ropa',
  'traje': 'Ropa', 'corbata': 'Ropa', 'aretes': 'Ropa', 'collar': 'Ropa',
  'pulsera': 'Ropa', 'anillo': 'Ropa',

  // ── Salud ──
  'farmacia': 'Salud', 'medicina': 'Salud', 'medicamento': 'Salud',
  'pastillas': 'Salud', 'vitaminas': 'Salud', 'doctor': 'Salud',
  'medico': 'Salud', 'hospital': 'Salud', 'clinica': 'Salud',
  'consulta': 'Salud', 'dentista': 'Salud', 'oculista': 'Salud',
  'psicologo': 'Salud', 'terapia': 'Salud', 'analisis': 'Salud',
  'laboratorio': 'Salud', 'similares': 'Salud', 'benavides': 'Salud',
  'inyeccion': 'Salud', 'vacuna': 'Salud', 'salud': 'Salud',
  'radiografia': 'Salud', 'ultrasonido': 'Salud', 'antibiotico': 'Salud',
  'cita medica': 'Salud', 'seguro medico': 'Salud',

  // ── Entretenimiento / Juegos ──
  'cine': 'Entretenimiento', 'pelicula': 'Entretenimiento',
  'teatro': 'Entretenimiento', 'concierto': 'Entretenimiento',
  'show': 'Entretenimiento', 'evento': 'Entretenimiento',
  'netflix': 'Entretenimiento', 'spotify': 'Entretenimiento',
  'amazon': 'Entretenimiento', 'disney': 'Entretenimiento',
  'hbo': 'Entretenimiento', 'suscripcion': 'Entretenimiento',
  'juego': 'Juegos', 'videojuego': 'Juegos', 'steam': 'Juegos',
  'playstation': 'Juegos', 'xbox': 'Juegos', 'nintendo': 'Juegos',
  'antro': 'Entretenimiento', 'bar': 'Entretenimiento',
  'discoteca': 'Entretenimiento', 'karaoke': 'Entretenimiento',
  'bowling': 'Entretenimiento', 'parque': 'Entretenimiento',
  'zoo': 'Entretenimiento', 'museo': 'Entretenimiento',
  'diversion': 'Entretenimiento', 'fiesta': 'Entretenimiento',
  'bailar': 'Entretenimiento', 'club': 'Entretenimiento',

  // ── Casa / Hogar ──
  'renta': 'Casa', 'alquiler': 'Casa', 'hipoteca': 'Casa',
  'predial': 'Casa', 'luz': 'Casa', 'electricidad': 'Casa', 'cfe': 'Casa',
  'internet': 'Casa', 'telmex': 'Casa', 'izzi': 'Casa', 'totalplay': 'Casa',
  'megacable': 'Casa', 'telefono': 'Casa', 'celular': 'Casa',
  'telcel': 'Casa', 'movistar': 'Casa', 'muebles': 'Casa',
  'silla': 'Casa', 'mesa': 'Casa', 'cama': 'Casa', 'sofa': 'Casa',
  'refrigerador': 'Casa', 'lavadora': 'Casa', 'estufa': 'Casa',
  'limpieza': 'Casa', 'plomero': 'Casa', 'mantenimiento': 'Casa',
  'hogar': 'Casa', 'casa': 'Casa', 'departamento': 'Casa',
  'gas': 'Casa', 'tinaco': 'Casa', 'pintura': 'Casa',

  // ── Educación ──
  'escuela': 'Educacion', 'colegio': 'Educacion', 'universidad': 'Educacion',
  'colegiatura': 'Educacion', 'matricula': 'Educacion',
  'inscripcion': 'Educacion', 'curso': 'Educacion', 'taller': 'Educacion',
  'diplomado': 'Educacion', 'maestria': 'Educacion', 'doctorado': 'Educacion',
  'libros': 'Educacion', 'utiles': 'Educacion', 'papeleria': 'Educacion',
  'cuadernos': 'Educacion', 'plumas': 'Educacion', 'mochila': 'Educacion',
  'udemy': 'Educacion', 'coursera': 'Educacion', 'platzi': 'Educacion',
  'tutorias': 'Educacion', 'clases': 'Educacion', 'libro': 'Educacion',
  'educacion': 'Educacion',

  // ── Gym / Deporte ──
  'gym': 'Gym', 'gimnasio': 'Gym', 'crossfit': 'Gym', 'yoga': 'Gym',
  'pilates': 'Gym', 'spinning': 'Gym', 'membresia': 'Gym',
  'smart fit': 'Gym', 'sport city': 'Gym', 'pesas': 'Gym',
  'proteina': 'Gym', 'suplementos': 'Gym', 'deporte': 'Gym',
  'ejercicio': 'Gym', 'correr': 'Gym', 'nadar': 'Gym',
  'natacion': 'Gym', 'futbol': 'Gym', 'basquet': 'Gym',

  // ── Viajes ──
  'viaje': 'Viajes', 'hotel': 'Viajes', 'hostal': 'Viajes',
  'airbnb': 'Viajes', 'booking': 'Viajes', 'avion': 'Viajes',
  'aeropuerto': 'Viajes', 'vuelo': 'Viajes', 'maleta': 'Viajes',
  'vacaciones': 'Viajes', 'tour': 'Viajes', 'excursion': 'Viajes',
  'crucero': 'Viajes', 'resort': 'Viajes',

  // ── Regalos ──
  'regalo': 'Regalo', 'obsequio': 'Regalo', 'cumpleanos': 'Regalo',
  'navidad': 'Regalo', 'san valentin': 'Regalo', 'flores': 'Regalo',
  'chocolates': 'Regalo', 'pastel': 'Regalo',

  // ── Mascotas ──
  'mascota': 'Mascotas', 'perro': 'Mascotas', 'gato': 'Mascotas',
  'veterinario': 'Mascotas', 'croquetas': 'Mascotas',

  // ── Ingresos ──
  'sueldo': 'Ingresos', 'salario': 'Ingresos', 'quincena': 'Ingresos',
  'deposito': 'Ingresos', 'transferencia': 'Ingresos', 'cobro': 'Ingresos',
  'venta': 'Ingresos', 'freelance': 'Ingresos', 'pago': 'Ingresos',
  'nomina': 'Ingresos', 'bono': 'Ingresos', 'comision': 'Ingresos',
};

// ─────────────────────────────────────────────────────────────────────────────
// Sinónimos de nombres de categorías del usuario
// Si el usuario tiene "Comida" y el NLP dice "Super", buscamos la mejor
// categoría disponible haciendo matching del alias con todas las del usuario.
// ─────────────────────────────────────────────────────────────────────────────

class SmartCategoryMatcher {
  final List<CategoryItem> userCategories;

  SmartCategoryMatcher(this.userCategories);

  /// Encuentra la mejor categoría del usuario dado el texto de voz.
  ///
  /// [voiceText] — texto normalizado (ya sin tildes, en minúsculas).
  /// [nlpCategory] — nombre de categoría que ya inferió el IntentParser.
  ///
  /// Retorna el [CategoryItem] más probable, o null si no hay match.
  CategoryItem? match(String voiceText, String? nlpCategory) {
    if (userCategories.isEmpty) return null;

    // ── Fase 1: Buscar palabras del texto en el diccionario de aliases ───
    // Escanea cada token del texto y acumula votos por categoría canónica.
    final votes = <String, double>{}; // categoryCanonical → score

    final tokens = voiceText.split(RegExp(r'[\s,]+'));
    for (final token in tokens) {
      if (token.length < 3) continue;
      // Match exacto en alias
      if (_semanticAliases.containsKey(token)) {
        final canonical = _semanticAliases[token]!;
        votes[canonical] = (votes[canonical] ?? 0) + 2.0;
      }
      // Match parcial (token contenido como subcadena de key de alias)
      for (final entry in _semanticAliases.entries) {
        if (entry.key.contains(token) || token.contains(entry.key)) {
          votes[entry.value] = (votes[entry.value] ?? 0) + 0.5;
        }
      }
    }

    // Añadir vote de la categoría NLP (de menor peso para no sobreponerse)
    if (nlpCategory != null) {
      votes[nlpCategory] = (votes[nlpCategory] ?? 0) + 1.0;
    }

    // ── Fase 2: Mapear categorías canónicas a categorías reales del usuario ─
    // Puntuación final para cada CategoryItem del usuario.
    final userScores = <CategoryItem, double>{};

    for (final item in userCategories) {
      double score = 0.0;
      final itemNorm = _normalize(item.name);

      // ¿Hay votos directos para esta categoría (por nombre normalizado)?
      for (final entry in votes.entries) {
        final canonNorm = _normalize(entry.key);
        // Match exacto nombre
        if (canonNorm == itemNorm) {
          score += entry.value * 3.0;
        }
        // Match parcial nombre (ej: "Entretenimiento" vs "Entret.")
        else if (canonNorm.contains(itemNorm) || itemNorm.contains(canonNorm)) {
          score += entry.value * 1.5;
        }
        // Similitud de tokens (primer token de cada palabra)
        else if (_tokenOverlap(canonNorm, itemNorm) > 0.5) {
          score += entry.value * 1.0;
        }
      }

      // ¿El nombre de la categoría aparece directamente en el texto?
      if (voiceText.contains(itemNorm)) {
        score += 5.0;
      }

      if (score > 0) userScores[item] = score;
    }

    if (userScores.isEmpty) return null;

    // Retornar la de mayor puntuación
    return userScores.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// Versión sin texto de voz — solo usa la categoría NLP.
  CategoryItem? matchFromNlpCategory(String? nlpCategory) {
    if (nlpCategory == null || userCategories.isEmpty) return null;
    final normNlp = _normalize(nlpCategory);
    CategoryItem? best;
    double bestScore = 0;

    for (final item in userCategories) {
      final normItem = _normalize(item.name);
      double score = 0;
      if (normItem == normNlp) {
        score = 10;
      } else if (normItem.contains(normNlp) || normNlp.contains(normItem)) {
        score = 6;
      } else if (_tokenOverlap(normItem, normNlp) > 0.4) {
        score = 3;
      }
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return best;
  }

  // ─── Utilidades ────────────────────────────────────────────
  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
      .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');

  /// Ratio de tokens compartidos entre dos cadenas.
  double _tokenOverlap(String a, String b) {
    final ta = a.split(RegExp(r'\s+')).toSet();
    final tb = b.split(RegExp(r'\s+')).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0;
    final intersection = ta.intersection(tb).length;
    final union = ta.union(tb).length;
    return intersection / union;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider de Riverpod para usar en la UI
// ─────────────────────────────────────────────────────────────────────────────
final smartCategoryMatcherProvider = Provider<SmartCategoryMatcher>((ref) {
  final categories = ref.watch(categoryProvider);
  return SmartCategoryMatcher(categories);
});
