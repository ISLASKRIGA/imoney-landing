class CategoryUtils {
  static String getEmoji(String? category) {
    if (category == null) return '📦';
    final cat = category.toLowerCase().trim();
    
    if (cat.contains('comida') || cat.contains('restaurante') || cat.contains('tacos') || cat.contains('pizza') || cat.contains('burger') || cat.contains('almuerzo') || cat.contains('cena')) return '🍔';
    
    if (cat.contains('transporte') || cat.contains('gasolina') || cat.contains('uber') || cat.contains('taxi') || cat.contains('bus') || cat.contains('auto') || cat.contains('coche')) return '🚗';
    
    if (cat.contains('ropa') || cat.contains('zapatos') || cat.contains('tenis') || cat.contains('jeans') || cat.contains('moda')) return '🛍️';
    
    if (cat.contains('juegos') || cat.contains('steam') || cat.contains('xbox') || cat.contains('cine') || cat.contains('pelicula') || cat.contains('netflix')) return '🎮';
    
    if (cat.contains('salud') || cat.contains('farmacia') || cat.contains('doctor') || cat.contains('hospital') || cat.contains('medicina')) return '💊';
    
    if (cat.contains('super') || cat.contains('despensa') || cat.contains('mercado') || cat.contains('oxxo') || cat.contains('walmart') || cat.contains('tienda')) return '🛒';
    
    if (cat.contains('casa') || cat.contains('renta') || cat.contains('luz') || cat.contains('agua') || cat.contains('internet') || cat.contains('gas') || cat.contains('hogar')) return '🏠';
    
    if (cat.contains('viaje') || cat.contains('hotel') || cat.contains('avion') || cat.contains('vuelo') || cat.contains('vacaciones')) return '✈️';
    
    if (cat.contains('regalo') || cat.contains('obsequio')) return '🎁';
    
    if (cat.contains('educacion') || cat.contains('escuela') || cat.contains('curso') || cat.contains('libro') || cat.contains('universidad')) return '📚';
    
    if (cat.contains('gym') || cat.contains('deporte') || cat.contains('fit') || cat.contains('ejercicio')) return '💪';
    
    if (cat.contains('ingreso') || cat.contains('sueldo') || cat.contains('deposito') || cat.contains('cobro') || cat.contains('dinero') || cat.contains('ventas') || cat.contains('pago')) return '💲';

    // Default fallback based on first letter or specific defaults
    if (cat.startsWith('a')) return '🅰️';
    if (cat.startsWith('b')) return '🅱️';
    if (cat.startsWith('c')) return '©️';
    
    return '📦'; 
  }
}
