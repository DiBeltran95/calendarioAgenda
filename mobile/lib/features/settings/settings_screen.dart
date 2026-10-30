import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/ui.dart';
import '../../data/sync.dart';
import '../auth/auth_screens.dart' show whatsappEnmascarado;
import '../notifications/notification_service.dart';
import '../onboarding/onboarding_screen.dart' show opcionesModulos;
import '../notifications/push_registro.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final prefs = ref.watch(preferenciasProvider).value ?? const Preferencias();
    final usuario = ref.watch(sesionProvider).value?.usuario;
    final repo = ref.read(ajustesRepoProvider);
    final activos = ref.watch(modulosActivosProvider);
    final permiso = ref.watch(permisoAvisosProvider).value;
    final programados = ref.watch(avisosProgramadosProvider);
    final push = ref.watch(estadoPushProvider);
    var i = 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.xxxl),
              children: [
                EncabezadoPantalla(titulo: 'Perfil', perfil: false, atras: Navigator.of(context).canPop()),
                // ── Perfil ──
                Entrance(
                  index: i++,
                  child: AppCard(
                    gradient: LinearGradient(colors: [Color.alphaBlend(p.accent.withValues(alpha: 0.14), p.surface), p.surface]),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [p.accent, p.accent2])),
                          child: Text(usuario?.iniciales ?? '', style: context.text.titleLarge?.copyWith(color: p.onAccent, fontWeight: FontWeight.w800)),
                        ),
                        const HGap.md(),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(usuario?.nombre ?? '', style: context.text.titleMedium),
                              Text(usuario?.email ?? '', style: context.text.bodySmall),
                              if ((usuario?.whatsapp ?? '').isNotEmpty)
                                Row(children: [
                                  const Icon(Icons.chat_rounded, size: 14, color: Brand.whatsapp),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(whatsappEnmascarado(usuario!.whatsapp), style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
                                  ),
                                ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VGap.lg(),
                // ── Módulos ──
                const SectionHeader('Módulos', icon: Icons.dashboard_customize_rounded, subtitle: 'Elige qué ver en la barra inferior. Tus datos no se borran.'),
                Entrance(
                  index: i++,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xxs),
                    child: Column(
                      children: [
                        for (final o in opcionesModulos)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: IconBadge(o.modulo.iconSelected, color: o.modulo.accent(Theme.of(context).brightness), size: 40),
                            value: activos.contains(o.modulo),
                            onChanged: (v) => repo.setModulos({...activos.where((m) => m != o.modulo), if (v) o.modulo}),
                            title: Text(o.modulo.label),
                            subtitle: Text(o.titulo, style: context.text.bodySmall),
                          ),
                      ],
                    ),
                  ),
                ),
                const VGap.lg(),
                // ── Notificaciones ──
                const SectionHeader('Notificaciones', icon: Icons.notifications_rounded),
                Entrance(
                  index: i++,
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const Icon(Icons.chat_rounded, color: Brand.whatsapp),
                          const HGap.sm(),
                          Expanded(
                            child: Text(
                              'Los recordatorios por WhatsApp los envía el servidor a tu número, aunque el teléfono esté apagado.',
                              style: context.text.bodyMedium,
                            ),
                          ),
                        ]),
                        const VGap.md(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: prefs.notificaciones,
                          onChanged: (v) async {
                            await repo.setNotificaciones(v);
                            if (v && permiso == PermisoAvisos.denegado) await ref.read(permisoAvisosProvider.notifier).pedir();
                          },
                          title: const Text('Avisos en este teléfono'),
                          subtitle: Text(_estadoPermiso(permiso, prefs.notificaciones, programados, push), style: context.text.bodySmall),
                        ),
                        if (prefs.notificaciones && permiso == PermisoAvisos.concedido) _CanalAvisos(push: push, programados: programados),
                        AnimatedSize(
                          duration: Motion.of(context, Motion.medium),
                          alignment: Alignment.topCenter,
                          child: !prefs.notificaciones
                              ? const SizedBox(width: double.infinity)
                              : Column(children: [
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: prefs.aviso30,
                                    onChanged: repo.setAviso30,
                                    title: const Text('30 minutos antes'),
                                    subtitle: Text('Además del aviso a la hora exacta.', style: context.text.bodySmall),
                                  ),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: prefs.resumenDiario,
                                    onChanged: repo.setResumenDiario,
                                    title: const Text('Resumen de las 7:00 a. m.'),
                                    subtitle: Text('Cumpleaños, pagos, cobros de tarjeta y festivos del día.', style: context.text.bodySmall),
                                  ),
                                  if (permiso == PermisoAvisos.denegado) ...[
                                    const VGap.xs(),
                                    FilledButton.tonalIcon(
                                      onPressed: () => ref.read(permisoAvisosProvider.notifier).pedir(),
                                      icon: const Icon(Icons.notifications_active_rounded),
                                      label: const Text('Permitir notificaciones'),
                                    ),
                                  ],
                                  if (permiso == PermisoAvisos.concedido) ...[
                                    const VGap.xs(),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final toaster = Toaster.of(context);
                                        try {
                                          await ref.read(servicioAvisosProvider).prueba();
                                          HapticFeedback.lightImpact();
                                          toaster.show('Llegará en ${ServicioAvisos.esperaPrueba.inSeconds} segundos. Minimiza la app para verla como te llegarán los avisos.');
                                        } catch (_) {
                                          toaster.show('No se pudo programar la prueba. Revisa el permiso de notificaciones en Ajustes del teléfono.', error: true);
                                        }
                                      },
                                      icon: const Icon(Icons.notification_add_rounded),
                                      label: const Text('Enviar una notificación de prueba'),
                                    ),
                                  ],
                                ]),
                        ),
                      ],
                    ),
                  ),
                ),
                const VGap.lg(),
                // ── Apariencia ──
                const SectionHeader('Apariencia', icon: Icons.palette_outlined),
                Entrance(
                  index: i++,
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Tema', style: context.text.labelMedium),
                        const VGap.xs(),
                        SegmentedPill<ThemeMode>(
                          options: const [
                            (ThemeMode.dark, 'Oscuro', Icons.dark_mode_rounded),
                            (ThemeMode.light, 'Claro', Icons.light_mode_rounded),
                            (ThemeMode.system, 'Sistema', Icons.brightness_auto_rounded),
                          ],
                          value: prefs.themeMode,
                          onChanged: repo.setTema,
                        ),
                        const VGap.sm(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: prefs.reducirMovimiento,
                          onChanged: repo.setReducirMovimiento,
                          title: const Text('Reducir animaciones'),
                          subtitle: Text('Desactiva transiciones y efectos de movimiento.', style: context.text.bodySmall),
                        ),
                      ],
                    ),
                  ),
                ),
                const VGap.lg(),
                // ── Datos y sesión ──
                const SectionHeader('Datos y sesión', icon: Icons.cloud_done_rounded),
                Entrance(
                  index: i++,
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Icon(Icons.sync_rounded, color: p.success, size: IconSizes.md),
                          const HGap.sm(),
                          Expanded(
                            child: Text(
                              'Tus datos viven en tu cuenta: los ves igual en la web (agendaservi.com) y en este teléfono. Aquí se guarda una copia para consultarlos sin internet.',
                              style: context.text.bodyMedium,
                            ),
                          ),
                        ]),
                        const VGap.md(),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final toaster = Toaster.of(context);
                            await ref.read(sincronizadorProvider).refrescarTodo();
                            toaster.show('Datos actualizados', icon: Icons.sync_rounded);
                          },
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Sincronizar ahora'),
                        ),
                        const VGap.sm(),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await confirmar(
                              context,
                              titulo: '¿Cerrar sesión?',
                              mensaje: 'Se borrará la copia local de tus datos y dejarás de recibir avisos en este teléfono. Tus WhatsApp seguirán llegando.',
                              confirmar: 'Cerrar sesión',
                              destructivo: true,
                              icon: Icons.logout_rounded,
                            );
                            if (!ok) return;
                            await ref.read(registroPushProvider).darDeBaja();
                            await ref.read(sesionProvider.notifier).cerrar();
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: p.danger, side: BorderSide(color: p.danger.withValues(alpha: 0.5))),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  ),
                ),
                const VGap.lg(),
                Center(child: Text('Agendaservi 2.1 · Flutter + Riverpod + Drift', style: context.text.bodySmall)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _estadoPermiso(PermisoAvisos? p, bool activas, int programados, EstadoPush push) {
    if (!activas) return 'Desactivadas: solo recibirás los WhatsApp.';
    return switch (p) {
      PermisoAvisos.concedido when push.confirmado => 'Activas · llegan desde el servidor a la misma hora que el WhatsApp.',
      PermisoAvisos.concedido => programados > 0 ? 'Activas · $programados aviso(s) programados para los próximos 14 días.' : 'Activas · sin avisos próximos.',
      PermisoAvisos.denegado => 'El sistema no ha dado permiso todavía.',
      PermisoAvisos.noSoportado => 'Este dispositivo no admite notificaciones locales (solo WhatsApp).',
      null => 'Comprobando permisos…',
    };
  }
}

/// Explica por qué vía llegan los avisos a este teléfono.
class _CanalAvisos extends StatelessWidget {
  const _CanalAvisos({required this.push, required this.programados});
  final EstadoPush push;
  final int programados;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (icono, color, titulo, detalle) = push.confirmado
        ? (
            Icons.cloud_done_rounded,
            p.success,
            'Al instante desde el servidor',
            'Te avisamos aunque no abras la app o hayas creado el evento en la web.',
          )
        : push.registrado
            ? (
                Icons.cloud_sync_rounded,
                p.accent,
                'Conectando con el servidor…',
                'Mientras llega la confirmación, los avisos quedan programados en el teléfono.',
              )
            : (
                Icons.phone_iphone_rounded,
                p.info,
                'Programados en este teléfono',
                'Se actualizan al abrir la app y, de vez en cuando, en segundo plano. El WhatsApp siempre llega.',
              );
    return Semantics(
      container: true,
      label: '$titulo. $detalle',
      child: ExcludeSemantics(
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.medium),
          child: Container(
            key: ValueKey(titulo),
            margin: const EdgeInsets.only(bottom: Gap.xs),
            padding: const EdgeInsets.all(Gap.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icono, color: color, size: IconSizes.md),
              const HGap.sm(),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo, style: context.text.labelLarge),
                  const SizedBox(height: 2),
                  Text(detalle, style: context.text.bodySmall),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
