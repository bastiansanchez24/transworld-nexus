import 'package:flutter/material.dart';

import '../constants/paises_evento.dart';

/// Selector único de país para eventos y actividades de captura.
class CampoPaisEvento extends StatelessWidget {
  const CampoPaisEvento({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: const Key('campo_pais_evento'),
      initialValue: normalizarPaisEvento(value),
      isExpanded: true,
      decoration: const InputDecoration(),
      items: const [
        DropdownMenuItem(value: kPaisEventoChile, child: Text('🇨🇱  Chile')),
        DropdownMenuItem(value: kPaisEventoPeru, child: Text('🇵🇪  Perú')),
      ],
      onChanged: !enabled
          ? null
          : (pais) {
              if (pais != null) onChanged(pais);
            },
      validator: (pais) =>
          kPaisesEvento.contains(pais) ? null : 'Selecciona Chile o Perú',
    );
  }
}
