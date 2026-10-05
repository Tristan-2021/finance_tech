/// Layout embebido: se usa cuando Remote Config no está disponible o el JSON
/// publicado no es válido. Debe parsear siempre (hay un test que lo verifica).
const String defaultHomeLayoutJson = '''
{
  "schema_version": 1,
  "default": [
    {"id": "tip_default", "type": "tip", "params": {"text": "Revisa tus movimientos con frecuencia."}},
    {"id": "spending_default", "type": "spending_summary"}
  ],
  "segments": {
    "joven": [
      {"id": "promo_joven", "type": "promo", "params": {"title": "Ahorra desde hoy", "body": "Activa tu meta de ahorro."}},
      {"id": "spending_joven", "type": "spending_summary"},
      {"id": "tip_joven", "type": "tip", "params": {"text": "Separa un 10% de cada ingreso."}}
    ],
    "adulto": [
      {"id": "spending_adulto", "type": "spending_summary"},
      {"id": "rate_adulto", "type": "exchange_rate", "params": {"pair": "USD/EUR", "rate": "0.92"}},
      {"id": "tip_adulto", "type": "tip", "params": {"text": "Revisa tus servicios recurrentes."}}
    ]
  }
}
''';
