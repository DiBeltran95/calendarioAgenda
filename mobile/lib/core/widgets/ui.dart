import 'package:flutter/material.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../motion.dart';

/// Superficie base: fondo de tarjeta, borde fino y radio grande.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.md),
    this.onTap,
    this.onLongPress,
    this.color,
    this.gradient,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final card = AnimatedContainer(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.standard,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? p.surface) : null,
        gradient: gradient,
        borderRadius: Radii.rLg,
        border: Border.all(color: borderColor ?? p.border),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    if (onTap == null && onLongPress == null) return card;
    return Pressable(onTap: onTap, onLongPress: onLongPress, semanticLabel: semanticLabel, scale: 0.985, child: card);
  }
}

/// Título de sección con acción opcional a la derecha.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.icon, this.action, this.subtitle});

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: IconSizes.md, color: p.accent),
            const HGap.xs(),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: context.text.titleMedium)),
                if (subtitle != null) Text(subtitle!, style: context.text.bodySmall),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Estado vacío con ícono, mensaje y acción opcional.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction, this.compact = false});

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? Gap.md : Gap.xl, horizontal: Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon, size: compact ? 48 : 64, color: p.textSecondary),
          const VGap.md(),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const VGap.xs(),
            Text(message!, style: context.text.bodyMedium?.copyWith(color: p.textSecondary), textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const VGap.md(),
            FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
              style: FilledButton.styleFrom(
                backgroundColor: p.accent.withValues(alpha: 0.16),
                foregroundColor: p.accent,
                minimumSize: const Size(0, 48),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Etiqueta pequeña de color (estado, tipo, badge).
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.color, this.icon, this.filled = false});

  final String label;
  final Color? color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xs, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: context.isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: filled ? context.palette.onAccent : c),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: filled ? context.palette.onAccent : c, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}

/// Métrica compacta: etiqueta arriba, valor grande abajo.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon, this.color, this.caption});

  final String label;
  final Widget value;
  final IconData? icon;
  final Color? color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.accent;
    return Container(
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: Radii.rMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[Icon(icon, size: IconSizes.sm, color: c), const SizedBox(width: 6)],
              Expanded(child: Text(label, style: context.text.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 6),
          DefaultTextStyle.merge(style: context.text.titleMedium?.copyWith(color: c, fontWeight: FontWeight.w700), child: value),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

/// Cabecera grande de cada módulo: saludo, título y acciones.
class ModuleHeader extends StatelessWidget {
  const ModuleHeader({super.key, required this.title, this.overline, this.actions = const []});

  final String title;
  final String? overline;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.xs, 0, Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null)
                  Text(overline!, style: context.text.labelMedium?.copyWith(color: p.accent, fontWeight: FontWeight.w600)),
                Semantics(header: true, child: Text(title, style: context.text.headlineMedium)),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Layout adaptable de un módulo: una columna en teléfono y dos paneles en
/// tablet / web ancho (calendario a la izquierda, detalle a la derecha).
class ModuleLayout extends StatelessWidget {
  const ModuleLayout({super.key, required this.primary, required this.secondary, this.bottomPadding = 120});

  final List<Widget> primary;
  final List<Widget> secondary;
  final double bottomPadding;

  static const breakpoint = 980.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= breakpoint;
      final side = c.maxWidth < 600 ? Gap.md : Gap.xl;
      if (!wide) {
        return ListView(
          padding: EdgeInsets.fromLTRB(side, Gap.xs, side, bottomPadding),
          children: [...primary, ...secondary],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: ListView(padding: EdgeInsets.fromLTRB(side, Gap.xs, Gap.md, bottomPadding), children: primary),
          ),
          Expanded(
            flex: 6,
            child: ListView(padding: EdgeInsets.fromLTRB(Gap.md, Gap.xl + Gap.xs, side, bottomPadding), children: secondary),
          ),
        ],
      );
    });
  }
}
