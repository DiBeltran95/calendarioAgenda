// Integración app ↔ API (contra el backend falso que imita a server.ts).

import 'package:agendaservi/core/dates.dart';
import 'package:agendaservi/core/providers.dart';
import 'package:agendaservi/core/session.dart';
import 'package:agendaservi/data/models.dart';
import 'package:agendaservi/data/sync.dart';
import 'package:agendaservi/features/auth/auth_repository.dart';
import 'package:agendaservi/features/cycle/cycle_repository.dart';
import 'package:agendaservi/features/events/events_repository.dart';
import 'package:agendaservi/features/finance/finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  group('modelos', () {
    test('parsea las formas de MySQL (DECIMAL texto, 0/1, TIME)', () {
      final e = Evento.fromJson({
        'id': 7,
        'titulo': 'SOAT',
        'fecha': '2026-09-23',
        'hora': '14:30:00',
        'costo': '185000.50',
        'tipo_transaccion': 'gasto',
        'estado_pago': 'pendiente',
        'frecuencia': 'anual',
        'parent_id': null,
        'tarjeta_credito_id': null,
      });
      expect(e.hora, '14:30');
      expect(e.costo, 185000.5);
      expect(Cuenta.fromJson({'id': 1, 'nombre': 'x', 'tipo': 'cdt', 'saldo': '1000.00', 'fecha_inicio': '2026-01-05T05:00:00.000Z'}).fechaInicio,
          isNotNull);
      expect(Meta.fromJson({'id': 1, 'nombre': 'm', 'monto_objetivo': '10', 'color': '#34E47E', 'completada': 1}).color, 0xFF34E47E);
      expect(Meta.fromJson({'id': 1, 'nombre': 'm', 'monto_objetivo': '10', 'completada': 1}).completada, isTrue);
    });
  });

  group('autenticación', () {
    test('login correcto guarda la sesión', () async {
      final (c, _) = await contenedor(sesion: null);
      final r = await c.read(authRepoProvider).iniciarSesion('diego@test.co', 'secreta');
      expect(r, isA<AuthOk>());
      await c.read(sesionProvider.notifier).iniciar((r as AuthOk).sesion);
      expect(c.read(sesionProvider).value?.usuario.nombre, 'Diego Beltrán');
      expect(c.read(usuarioIdProvider), 1);
    });

    test('clave incorrecta: mensaje del servidor, sin cerrar sesiones', () async {
      final (c, _) = await contenedor(sesion: null);
      expect(() => c.read(authRepoProvider).iniciarSesion('diego@test.co', 'mala'), throwsA(isA<AuthError>().having((e) => e.mensaje, 'mensaje', 'Credenciales inválidas')));
    });

    test('registro → código por WhatsApp → verificación', () async {
      final (c, backend) = await contenedor(sesion: null);
      final auth = c.read(authRepoProvider);
      final v = await auth.registrar(nombre: 'Ana', email: 'ana@test.co', password: 'clave123', whatsapp: '573115556677');
      expect(v.email, 'ana@test.co');
      expect(() => auth.verificar('ana@test.co', '000000'), throwsA(isA<AuthError>()));
      final s = await auth.verificar('ana@test.co', '123456');
      expect(s.usuario.nombre, 'Ana');
      // Una cuenta sin verificar que intenta entrar va a verificación (403).
      backend.usuarios.add({'id': 99, 'nombre': 'Luis', 'email': 'luis@test.co', 'password': 'x', 'whatsapp': '57300', 'verificado': 0});
      expect(await auth.iniciarSesion('luis@test.co', 'x'), isA<AuthVerificar>());
    });

    test('un 401 en una ruta autenticada cierra la sesión con aviso', () async {
      final (c, _) = await contenedor(sesion: const Sesion(token: 'invalido', usuario: Usuario(id: 1, nombre: 'D', email: 'd')));
      await expectLater(c.read(bootstrapProvider.future), throwsA(anything));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(sesionProvider).value, isNull);
      expect(c.read(avisoSesionProvider), contains('expiró'));
    });
  });

  group('eventos', () {
    test('un evento anual crea sus repeticiones y aparece en el mes', () async {
      final (c, backend) = await contenedor();
      final sub = c.listen(monthProvider((2026, 9)), (_, _) {});
      await c.read(monthProvider((2026, 9)).future);
      await c.read(eventsRepoProvider).crear(const EventoInput(titulo: 'SOAT moto', fecha: '2026-09-23', hora: '09:00', categoria: 'moto', frecuencia: 'anual'));
      expect(backend.eventos, hasLength(6));
      final mes = c.read(monthProvider((2026, 9))).value!;
      expect(mes.eventos.single.titulo, 'SOAT moto');
      expect(mes.eventos.single.hora, '09:00');
      sub.close();
    });

    test('marcar pagado es optimista y se confirma en el servidor', () async {
      final (c, backend) = await contenedor();
      final sub = c.listen(monthProvider((2026, 9)), (_, _) {});
      await c.read(eventsRepoProvider).crear(const EventoInput(titulo: 'Arriendo', fecha: '2026-09-05', categoria: 'arriendo', tipoTransaccion: 'gasto', costo: 900000));
      final e = c.read(monthProvider((2026, 9))).value!.eventos.single;
      final f = c.read(eventsRepoProvider).alternarPago(e);
      expect(c.read(monthProvider((2026, 9))).value!.eventos.single.pagado, isTrue); // antes de la respuesta
      await f;
      expect(backend.eventos.single['estado_pago'], 'pagado');
      sub.close();
    });

    test('borrar "este y los siguientes" usa deleteMode=future', () async {
      final (c, backend) = await contenedor();
      await c.read(eventsRepoProvider).crear(const EventoInput(titulo: 'Gym', fecha: '2026-01-10', frecuencia: 'mensual'));
      final marzo = Evento.fromJson(backend.eventos.firstWhere((e) => e['fecha'] == '2026-03-10'));
      await c.read(eventsRepoProvider).eliminar(marzo, AlcanceSerie.esteYFuturos);
      expect(backend.eventos.map((e) => e['fecha']), ['2026-01-10', '2026-02-10']);
    });

    test('cumpleaños van al bootstrap', () async {
      final (c, _) = await contenedor();
      final sub = c.listen(bootstrapProvider, (_, _) {});
      await c.read(bootstrapProvider.future);
      await c.read(eventsRepoProvider).crearCumple(const CumpleInput(nombre: 'Mamá', fecha: '2026-10-02', anioNacimiento: 1965));
      expect(c.read(bootstrapProvider).value!.cumples.single.nombre, 'Mamá');
      sub.close();
    });
  });

  group('ciclo', () {
    test('errores del servidor llegan como CicloError y el aviso se conserva', () async {
      final (c, _) = await contenedor();
      final repo = c.read(cycleRepoProvider);
      await repo.guardarPeriodo(fecha: '2026-08-01', diasSangrado: 5);
      expect(() => repo.guardarPeriodo(fecha: '2026-08-01'), throwsA(isA<CicloError>().having((e) => e.mensaje, 'm', contains('Ya tienes'))));
      final r = await repo.guardarPeriodo(fecha: '2026-08-06');
      expect(r.advertencia, contains('5 día(s)'));
    });

    test('el registro diario de síntomas es local y por usuario', () async {
      final (c, backend) = await contenedor();
      // En Riverpod 3 un provider sin oyentes se pausa: se escucha como en la UI.
      final sub = c.listen(registrosDiaProvider, (_, _) {});
      await c.read(cycleRepoProvider).guardarRegistroDia(fecha: '2026-09-23', flujo: 2, animo: 'feliz', sintomas: {'colicos'});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(registrosDiaProvider).value?['2026-09-23']?.flujo, 2);
      sub.close();
      expect(backend.log.where((l) => l.contains('registro')), isEmpty);
    });
  });

  group('finanzas', () {
    test('compra a 3 cuotas con tarjeta: deuda y cobros en el calendario', () async {
      final (c, backend) = await contenedor();
      final fin = c.read(financeRepoProvider);
      final tc = await fin.crearCuenta(const CuentaInput(nombre: 'Visa', tipo: 'tarjeta_credito', limite: 5000000, diaCorte: 15));
      await fin.crearTransaccion(TransaccionInput(tipo: 'gasto', monto: 900000, descripcion: 'Celular', fecha: '2026-09-20', cuentaId: tc, cuotas: 3));
      final boot = await c.read(bootstrapProvider.future);
      expect(boot.cuentas.single.saldo, 900000);
      final cobros = backend.eventos.where((e) => e['transaccion_id'] != null).map((e) => e['fecha']);
      expect(cobros, ['2026-10-15', '2026-11-15', '2026-12-15']);
    });

    test('aportar a una meta desde una cuenta registra el gasto y suma a la meta', () async {
      final (c, backend) = await contenedor();
      final fin = c.read(financeRepoProvider);
      final ah = await fin.crearCuenta(const CuentaInput(nombre: 'Ahorros', tipo: 'ahorros', saldo: 500000));
      await fin.crearMeta(const MetaInput(nombre: 'Viaje', montoObjetivo: 400000, montoActual: 100000));
      final meta = (await c.read(bootstrapProvider.future)).metas.single;
      final cumplida = await fin.aportarAMeta(meta, 300000, cuentaId: ah, fecha: '2026-09-22');
      expect(cumplida, isTrue);
      expect(backend.metas.single['monto_actual'], '400000.00');
      expect(backend.metas.single['completada'], 1);
      expect(backend.cuentas.single['saldo'], '200000.00');
    });

    test('verificar un ingreso planificado y deshacerlo', () async {
      final (c, backend) = await contenedor();
      final fin = c.read(financeRepoProvider);
      final ah = await fin.crearCuenta(const CuentaInput(nombre: 'Nómina', tipo: 'ahorros'));
      await fin.crearPlan(descripcion: 'Salario', monto: 3000000, frecuencia: 'quincenal', fechaInicio: '2026-01-15', cuentaId: ah);
      final plan = (await c.read(bootstrapProvider.future)).planes.single;
      await fin.verificarIngreso(plan: plan, fechaEsperada: '2026-09-12', fechaReal: '2026-09-11', montoReal: 2950000);
      expect(backend.cuentas.single['saldo'], '2950000.00');
      await expectLater(
        fin.verificarIngreso(plan: plan, fechaEsperada: '2026-09-12', fechaReal: '2026-09-12', montoReal: 1),
        throwsA(isA<FinanzasError>()),
      );
      final v = (await c.read(bootstrapProvider.future)).verificaciones.single;
      await fin.deshacerVerificacion(v);
      expect(backend.cuentas.single['saldo'], '0.00');
    });

    test('quitar un presupuesto borra todos los meses de esa categoría', () async {
      final (c, backend) = await contenedor();
      final sub = c.listen(presupuestosProvider, (_, _) {});
      final fin = c.read(financeRepoProvider);
      await fin.guardarPresupuesto(categoria: 'comida', limite: 800000, mes: 7, anio: 2026);
      await fin.guardarPresupuesto(categoria: 'comida', limite: 850000, mes: 8, anio: 2026);
      await c.read(presupuestosProvider.future);
      await fin.quitarPresupuesto('comida');
      expect(backend.presupuestos, isEmpty);
      sub.close();
    });

    test('categoría en uso: el servidor rechaza el borrado', () async {
      final (c, _) = await contenedor();
      final fin = c.read(financeRepoProvider);
      await fin.crearCategoria('Mascotas', 'pets');
      await fin.crearTransaccion(const TransaccionInput(tipo: 'gasto', monto: 20000, descripcion: 'Concentrado', fecha: '2026-09-01', categoria: 'mascotas'));
      final cat = (await c.read(bootstrapProvider.future)).categorias.firstWhere((x) => x.valor == 'mascotas');
      expect(() => fin.eliminarCategoria(cat), throwsA(isA<FinanzasError>()));
    });
  });

  group('caché y sin conexión', () {
    test('con el servidor caído se muestra lo guardado y se marca sin conexión', () async {
      final (c, backend) = await contenedor();
      await c.read(eventsRepoProvider).crear(EventoInput(titulo: 'Cita', fecha: hoyYmd(), hora: '10:00', categoria: 'doctor'));
      final ahora = DateTime.now();
      final k = (ahora.year, ahora.month);
      var sub = c.listen(monthProvider(k), (_, _) {});
      await c.read(monthProvider(k).future);
      sub.close();
      await Future<void>.delayed(Duration.zero);

      backend.caido = true;
      c.invalidate(monthProvider(k));
      sub = c.listen(monthProvider(k), (_, _) {});
      final desdeCache = await c.read(monthProvider(k).future);
      expect(desdeCache.eventos.single.titulo, 'Cita');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.read(redProvider), EstadoRed.sinConexion);
      sub.close();
    });

    test('cerrar sesión borra la caché local', () async {
      final (c, _) = await contenedor();
      await c.read(bootstrapProvider.future);
      await c.read(sesionProvider.notifier).cerrar();
      final db = c.read(databaseProvider);
      expect(await db.select(db.cacheEntries).get(), isEmpty);
    });
  });
}
