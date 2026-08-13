import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/nexus_components.dart';
import '../../../data/models/perfil.dart';

/// Lista de usuarios `user` / `externo` que pueden autorizarse a un evento.
class SelectorUsuariosAcceso extends StatefulWidget {
  const SelectorUsuariosAcceso({
    super.key,
    required this.usuarios,
    required this.seleccionados,
    required this.onChanged,
    this.enabled = true,
    this.permiteNuevosExternos = true,
    this.emptyHelperText =
        'Sin usuarios asignados: solo administradores y organizadores verán el evento.',
    this.errorText,
  });

  final List<Perfil> usuarios;
  final Set<String> seleccionados;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;
  final bool permiteNuevosExternos;
  final String emptyHelperText;
  final String? errorText;

  @override
  State<SelectorUsuariosAcceso> createState() => _SelectorUsuariosAccesoState();
}

class _SelectorUsuariosAccesoState extends State<SelectorUsuariosAcceso> {
  final _busquedaController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  List<Perfil> get _ordenados {
    return List<Perfil>.from(widget.usuarios)..sort(
      (a, b) => a.nombreCompleto.toLowerCase().compareTo(
        b.nombreCompleto.toLowerCase(),
      ),
    );
  }

  List<Perfil> get _filtrados {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _ordenados;
    return _ordenados
        .where(
          (u) =>
              u.nombreCompleto.toLowerCase().contains(q) ||
              u.rol.label.toLowerCase().contains(q),
        )
        .toList();
  }

  bool _puedeMarcar(Perfil usuario) {
    if (!widget.enabled) return false;
    if (widget.seleccionados.contains(usuario.id)) return true;
    if (usuario.isExterno && !widget.permiteNuevosExternos) return false;
    return true;
  }

  void _toggle(Perfil usuario) {
    if (!_puedeMarcar(usuario)) return;
    final next = {...widget.seleccionados};
    if (next.contains(usuario.id)) {
      next.remove(usuario.id);
    } else {
      next.add(usuario.id);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _busquedaController,
          enabled: widget.enabled,
          decoration: const InputDecoration(
            hintText: 'Buscar usuarios…',
            prefixIcon: Icon(Symbols.search_rounded, size: 20),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 360),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: widget.errorText != null
                  ? AppColors.danger
                  : AppColors.border,
            ),
          ),
          child: filtrados.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay usuarios para mostrar.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final usuario = filtrados[index];
                    final checked = widget.seleccionados.contains(usuario.id);
                    final habilitado = _puedeMarcar(usuario);
                    final bloqueadoExterno =
                        usuario.isExterno &&
                        !widget.permiteNuevosExternos &&
                        !checked;

                    return CheckboxListTile(
                      dense: true,
                      value: checked,
                      onChanged: habilitado ? (_) => _toggle(usuario) : null,
                      controlAffinity: ListTileControlAffinity.leading,
                      secondary: StatusChip(
                        label: usuario.rol.label,
                        variant: usuario.isExterno
                            ? StatusChipVariant.warning
                            : StatusChipVariant.neutral,
                      ),
                      title: Text(
                        usuario.nombreCompleto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: habilitado
                              ? AppColors.ink
                              : AppColors.textTertiary,
                        ),
                      ),
                      subtitle: bloqueadoExterno || !usuario.activo
                          ? Text(
                              bloqueadoExterno
                                  ? 'Solo eventos activos'
                                  : 'Inactivo',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: const TextStyle(fontSize: 12, color: AppColors.danger),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text(
            widget.seleccionados.isEmpty
                ? widget.emptyHelperText
                : '${widget.seleccionados.length} usuario'
                      '${widget.seleccionados.length == 1 ? '' : 's'} '
                      'con acceso.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
