import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/utils/user_facing_error.dart';

void main() {
  test('convierte el 422 de AE171 en un mensaje claro sin JSON', () {
    const raw = 'batch_uuid=abc statusCode=422 body={"detail":{"errors":'
        '[{"instrument_code":"AE171","message":"Parametro no permitido"}]}}';
    final message = userFacingSyncError(raw);

    expect(message, contains('AE171'));
    expect(message, contains('ya no está habilitada'));
    expect(message, isNot(contains('{')));
    expect(message, isNot(contains('body=')));
  });

  test('oculta consultas SQL y detalles internos', () {
    const raw = 'SQLAlchemyError: SELECT * FROM instrumentos WHERE id = 237';
    final message = userFacingSyncError(raw);

    expect(message, contains('contactá a soporte'));
    expect(message.toLowerCase(), isNot(contains('select')));
    expect(message.toLowerCase(), isNot(contains('sql')));
  });

  test('convierte respuestas JSON desconocidas en mensaje generico', () {
    const raw = '{"detail":"internal stack trace","query":"UPDATE x"}';
    final message = userFacingSyncError(raw);

    expect(message, contains('contactá a soporte'));
    expect(message, isNot(contains('{')));
  });

  test('mantiene mensajes operativos seguros', () {
    const raw = 'La planilla contiene valores inválidos o incompletos: AE171';
    expect(userFacingSyncError(raw), raw);
  });
}
