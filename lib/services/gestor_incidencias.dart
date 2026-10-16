import '../data/almacen_local.dart';
import '../model/incidencia.dart';

class GestorIncidencias {
  final AlmacenLocal datos = AlmacenLocal();
  List<Incidencia> incidencias = [];
  int cantidadPendientes = 0;

  Future<void> iniciar() async {
    incidencias = await datos.leer();
    cantidadPendientes =
        incidencias.where((x) => x.estado == 'Pendiente').length;
  }

  List<Incidencia> buscar(String texto) {
    final consulta = texto.trim().toLowerCase();
    if (consulta.isEmpty) return incidencias;
    return incidencias.where((x) {
      return x.titulo.toLowerCase().contains(consulta) ||
          x.descripcion.toLowerCase().contains(consulta);
    }).toList();
  }

  List<Incidencia> filtrar(
    String texto, {
    String estado = 'Todos',
    String prioridad = 'Todas',
  }) {
    return buscar(texto).where((incidencia) {
      return (estado == 'Todos' || incidencia.estado == estado) &&
          (prioridad == 'Todas' || incidencia.prioridad == prioridad);
    }).toList();
  }

  Incidencia? porId(String id) {
    for (var x in incidencias) {
      if (x.id == id) return x;
    }
    return null;
  }

  int contar(String estado) {
    if (estado == 'Pendiente') return cantidadPendientes;
    return incidencias.where((x) => x.estado == estado).length;
  }

  Future<void> cambiarEstado(String id, String estado) async {
    final incidencia = porId(id);
    if (incidencia == null) {
      throw StateError('No existe una incidencia con el ID $id');
    }

    final estadoAnterior = incidencia.estado;
    incidencia.estado = estado;
    try {
      await datos.guardar(incidencias);
    } catch (_) {
      incidencia.estado = estadoAnterior;
      rethrow;
    }
    cantidadPendientes =
        incidencias.where((x) => x.estado == 'Pendiente').length;
  }

  Future<void> cambiarPrioridad(String id, String prioridad) async {
    if (!Incidencia.prioridadesValidas.contains(prioridad)) {
      throw ArgumentError.value(prioridad, 'prioridad', 'Prioridad no válida');
    }

    final incidencia = porId(id);
    if (incidencia == null) {
      throw StateError('No existe una incidencia con el ID $id');
    }

    final prioridadAnterior = incidencia.prioridad;
    incidencia.prioridad = prioridad;
    try {
      await datos.guardar(incidencias);
    } catch (_) {
      incidencia.prioridad = prioridadAnterior;
      rethrow;
    }
  }

  Future<void> crear(
      String titulo, String descripcion, String cliente, String categoria,
      {String prioridad = 'Media'}) async {
    if (!Incidencia.prioridadesValidas.contains(prioridad)) {
      throw ArgumentError.value(prioridad, 'prioridad', 'Prioridad no válida');
    }

    final nuevo = Incidencia(
      id: 'INC-${DateTime.now().microsecondsSinceEpoch}',
      titulo: titulo,
      descripcion: descripcion,
      cliente: cliente,
      categoria: categoria,
      estado: 'Pendiente',
      fecha: DateTime.now().toIso8601String().split('T').first,
      prioridad: prioridad,
    );
    incidencias.insert(0, nuevo);
    cantidadPendientes++;
    await datos.guardar(incidencias);
  }

  Future<void> reiniciarDemo() async {
    await datos.restaurarDatosDeEjemplo();
    await iniciar();
  }
}
