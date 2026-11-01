/// Dirección de la página del televisor en modo "solo el canal de pesca": queda al lado de la cartelera
/// (…/sandytv/cartelera.json → …/sandytv/p/?solo=pesca).
Uri urlCanalPesca(Uri cartelera) {
  final partes = List<String>.of(cartelera.pathSegments);
  if (partes.isNotEmpty) partes.removeLast();
  return cartelera.replace(pathSegments: [...partes, 'p', ''], query: 'solo=pesca');
}
