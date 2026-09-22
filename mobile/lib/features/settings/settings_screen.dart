import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/ui.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final prefs = ref.watch(preferenciasProvider).value ?? const Preferencias();
    final repo = ref.read(ajustesRepoProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.xxxl),
              children: [
                const ModuleHeader(overline: 'Agendaservi', title: 'Ajustes'),
                Entrance(
                  child: AppCard(
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset('assets/images/logo.png', width: 56, height: 56),
                        ),
                        const HGap.md(),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(prefs.nombre.isEmpty ? 'Sin nombre' : prefs.nombre, style: context.text.titleMedium),
                              Text('Toca para cambiar tu nombre', style: context.text.bodySmall),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Editar nombre',
                          onPressed: () => _editarNombre(context, ref, prefs.nombre),
                          icon: const Icon(Icons.edit_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const VGap.lg(),
                const SectionHeader('Apariencia', icon: Icons.palette_outlined),
                Entrance(
                  index: 1,
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
                const SectionHeader('Tus datos', icon: Icons.storage_rounded),
                Entrance(
                  index: 2,
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Icon(Icons.lock_rounded, color: p.success, size: IconSizes.md),
                          const HGap.sm(),
                          Expanded(
                            child: Text(
                              'Todo se guarda en una base de datos SQLite dentro de este dispositivo. Funciona sin internet.',
                              style: context.text.bodyMedium,
                            ),
                          ),
                        ]),
                        const VGap.md(),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await confirmar(
                              context,
                              titulo: '¿Borrar todos los datos?',
                              mensaje: 'Se eliminarán eventos, ciclos, cuentas, movimientos, metas y presupuestos. Esta acción no se puede deshacer.',
                              confirmar: 'Borrar todo',
                              destructivo: true,
                              icon: Icons.warning_amber_rounded,
                            );
                            if (!ok) return;
                            final nombre = prefs.nombre;
                            await ref.read(databaseProvider).reiniciar();
                            // Conservamos la bienvenida y el nombre: solo se borran los datos.
                            await repo.marcarBienvenida();
                            await repo.setNombre(nombre);
                            if (context.mounted) toast(context, 'Datos borrados', icon: Icons.delete_sweep_rounded);
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: p.danger, side: BorderSide(color: p.danger.withValues(alpha: 0.5))),
                          icon: const Icon(Icons.delete_sweep_rounded),
                          label: const Text('Borrar todos los datos'),
                        ),
                      ],
                    ),
                  ),
                ),
                const VGap.lg(),
                Center(child: Text('Agendaservi 1.0 · Flutter + Riverpod + Drift', style: context.text.bodySmall)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editarNombre(BuildContext context, WidgetRef ref, String actual) async {
    final c = TextEditingController(text: actual);
    await showAppSheet(
      context,
      (ctx) => SheetScaffold(
        title: 'Tu nombre',
        icon: Icons.person_rounded,
        primaryLabel: 'Guardar',
        onPrimary: () async {
          await ref.read(ajustesRepoProvider).setNombre(c.text);
          if (ctx.mounted) Navigator.pop(ctx);
        },
        children: [
          const FieldLabel('Nombre'),
          TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words),
        ],
      ),
    );
    c.dispose();
  }
}
