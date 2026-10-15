import 'package:flutter_test/flutter_test.dart';
import 'package:nexasoft_incidencias/model/incidencia.dart';
import 'package:nexasoft_incidencias/services/gestor_incidencias.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Una incidencia antigua puede convertirse desde JSON', () {
    final registro = Incidencia.desdeJson({
      'id': 'INC-DEMO',
      'titulo': 'Prueba',
      'descripcion': 'Caso de ejemplo',
      'cliente': 'Cliente ficticio',
      'categoria': 'Redes',
      'estado': 'Pendiente',
      'fecha': '2026-10-12',
    });
    expect(registro.id, 'INC-DEMO');
    expect(registro.toJson()['estado'], 'Pendiente');
  });

  test(
      'El cambio de estado y los registros nuevos sobreviven al reiniciar el gestor',
      () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final gestor = GestorIncidencias();
    await gestor.iniciar();

    expect(gestor.porId('INC-101')!.estado, 'Pendiente');
    final estadoAnteriorDeOtroRegistro = gestor.porId('INC-102')!.estado;
    await gestor.cambiarEstado('INC-101', 'Resuelta');

    final gestorTrasReinicio = GestorIncidencias();
    await gestorTrasReinicio.iniciar();

    expect(gestorTrasReinicio.porId('INC-101')!.estado, 'Resuelta');
    expect(
      gestorTrasReinicio.porId('INC-102')!.estado,
      estadoAnteriorDeOtroRegistro,
    );

    await gestorTrasReinicio.crear(
      'Incidencia de prueba',
      'Descripción de prueba',
      'Cliente de prueba',
      'Software',
    );
    final idNuevo = gestorTrasReinicio.incidencias.first.id;

    final gestorTrasSegundoReinicio = GestorIncidencias();
    await gestorTrasSegundoReinicio.iniciar();

    expect(gestorTrasSegundoReinicio.porId(idNuevo), isNotNull);
    expect(gestorTrasSegundoReinicio.porId('INC-101')!.estado, 'Resuelta');
  });
}
