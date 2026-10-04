/// Traduce `offset`/`limit` al rango inclusivo que espera `.range(from, to)`.
/// Ejemplo: offset 20, limit 20 -> 20..39.
({int from, int to}) pageRange(int offset, int limit) {
  assert(offset >= 0 && limit > 0, 'offset >= 0 y limit > 0');
  return (from: offset, to: offset + limit - 1);
}
