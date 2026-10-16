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
    expect(registro.prioridad, 'Media');
    expect(registro.toJson()['prioridad'], 'Media');
  });

  test('La prioridad inválida de un registro antiguo usa Media', () {
    final registro = Incidencia.desdeJson({
      'id': 'INC-ANTIGUA',
      'prioridad': 'Urgente',
    });

    expect(registro.prioridad, 'Media');
  });

  test('La búsqueda incluye título y descripción sin distinguir mayúsculas',
      () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final gestor = GestorIncidencias();
    await gestor.iniciar();

    expect(gestor.buscar('wifi').single.id, 'INC-102');
    expect(gestor.buscar('WiFi').single.id, 'INC-102');
    expect(gestor.buscar('túnel').single.id, 'INC-106');
    expect(gestor.buscar('  ').length, gestor.incidencias.length);
  });

  test('Los filtros de texto, estado y prioridad se combinan', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final gestor = GestorIncidencias();
    await gestor.iniciar();
    await gestor.cambiarPrioridad('INC-101', 'Alta');

    expect(
      gestor
          .filtrar(
            'impresora',
            estado: 'Pendiente',
            prioridad: 'Alta',
          )
          .map((incidencia) => incidencia.id),
      ['INC-101'],
    );
    expect(
      gestor.filtrar(
        'wifi',
        estado: 'Pendiente',
        prioridad: 'Alta',
      ),
      isEmpty,
    );
    expect(
      gestor.filtrar('').length,
      gestor.incidencias.length,
    );
  });

  test('No permite asignar prioridades fuera de las opciones aprobadas',
      () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final gestor = GestorIncidencias();
    await gestor.iniciar();

    await expectLater(
      gestor.cambiarPrioridad('INC-101', 'Urgente'),
      throwsArgumentError,
    );
    expect(gestor.porId('INC-101')!.prioridad, 'Media');
    await expectLater(
      gestor.crear('Caso', 'Descripción', 'Cliente', 'Software',
          prioridad: 'Urgente'),
      throwsArgumentError,
    );
  });

  test(
      'El cambio de estado y los registros nuevos sobreviven al reiniciar el gestor',
      () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final gestor = GestorIncidencias();
    await gestor.iniciar();

    expect(gestor.porId('INC-101')!.estado, 'Pendiente');
    expect(gestor.contar('Pendiente'), 5);
    expect(gestor.contar('En proceso'), 2);
    expect(gestor.contar('Resuelta'), 3);
    final estadoAnteriorDeOtroRegistro = gestor.porId('INC-102')!.estado;
    await gestor.cambiarEstado('INC-101', 'Resuelta');
    await gestor.cambiarPrioridad('INC-101', 'Alta');
    expect(gestor.contar('Pendiente'), 4);
    expect(gestor.contar('Resuelta'), 4);
    expect(gestor.contar('En proceso'), 2);
    expect(gestor.buscar('WiFi').length, 1);
    expect(gestor.contar('Pendiente'), 4);
    await gestor.cambiarEstado('INC-101', 'Pendiente');
    expect(gestor.contar('Pendiente'), 5);
    await gestor.cambiarEstado('INC-101', 'Resuelta');

    final gestorTrasReinicio = GestorIncidencias();
    await gestorTrasReinicio.iniciar();

    expect(gestorTrasReinicio.porId('INC-101')!.estado, 'Resuelta');
    expect(gestorTrasReinicio.porId('INC-101')!.prioridad, 'Alta');
    expect(gestorTrasReinicio.contar('Pendiente'), 4);
    expect(gestorTrasReinicio.contar('Resuelta'), 4);
    expect(
      gestorTrasReinicio.porId('INC-102')!.estado,
      estadoAnteriorDeOtroRegistro,
    );

    await gestorTrasReinicio.crear(
      'Incidencia de prueba',
      'Descripción de prueba',
      'Cliente de prueba',
      'Software',
      prioridad: 'Alta',
    );
    expect(gestorTrasReinicio.contar('Pendiente'), 5);
    final idNuevo = gestorTrasReinicio.incidencias.first.id;

    final gestorTrasSegundoReinicio = GestorIncidencias();
    await gestorTrasSegundoReinicio.iniciar();

    expect(gestorTrasSegundoReinicio.porId(idNuevo), isNotNull);
    expect(gestorTrasSegundoReinicio.porId('INC-101')!.estado, 'Resuelta');
    expect(gestorTrasSegundoReinicio.porId('INC-101')!.prioridad, 'Alta');
    expect(gestorTrasSegundoReinicio.porId(idNuevo)!.prioridad, 'Alta');
    expect(gestorTrasSegundoReinicio.contar('Pendiente'), 5);
    expect(gestorTrasSegundoReinicio.contar('Resuelta'), 4);
  });
}
