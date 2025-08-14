import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/fabrics.service.dart';

Future<void> showFabricEditorSheet(BuildContext context, Map<String, dynamic> fabric) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => FabricEditorSheet(fabric: fabric),
  );
}

class FabricEditorSheet extends StatefulWidget {
  final Map<String, dynamic> fabric;
  const FabricEditorSheet({super.key, required this.fabric});

  @override
  State<FabricEditorSheet> createState() => _FabricEditorSheetState();
}

class _FabricEditorSheetState extends State<FabricEditorSheet> {
  late final TextEditingController titleCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController typeCtrl;
  late final TextEditingController colorCtrl;
  String? newImagePath;

  @override
  void initState() {
    super.initState();
    final fabric = widget.fabric;
    titleCtrl = TextEditingController(text: (fabric['title'] ?? fabric['name'] ?? '') as String);
    descCtrl = TextEditingController(text: (fabric['description'] ?? '') as String);
    typeCtrl = TextEditingController(text: (fabric['type'] ?? '') as String);
    colorCtrl = TextEditingController(text: (fabric['color'] ?? '') as String);
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    typeCtrl.dispose();
    colorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Modifier le tissu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 8),
            _LabeledField(label: 'Titre', controller: titleCtrl),
            const SizedBox(height: 12),
            _LabeledField(label: 'Description', controller: descCtrl, maxLines: 3),
            const SizedBox(height: 12),
            _LabeledField(label: 'Type', controller: typeCtrl),
            const SizedBox(height: 12),
            _LabeledField(label: 'Couleur', controller: colorCtrl),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1920, maxHeight: 1080);
                    if (img != null && mounted) {
                      setState(() => newImagePath = img.path);
                    }
                  },
                  icon: const Icon(Icons.image),
                  label: Text(newImagePath == null ? 'Changer l\'image' : 'Image sélectionnée'),
                ),
                const SizedBox(width: 12),
                if (newImagePath != null)
                  Expanded(
                    child: Text(
                      newImagePath!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
    SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
      final id = widget.fabric['id'] as String?;
      if (id == null) return;
      final data = {
                    'title': titleCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'type': typeCtrl.text.trim(),
                    'color': colorCtrl.text.trim(),
                  };
      final navigator = Navigator.of(context);
      final svc = context.read<FabricsService>();
                  bool ok;
                  if (newImagePath != null && newImagePath!.isNotEmpty) {
                    ok = await svc.updateFabricWithImage(id, data, newImagePath!);
                  } else {
                    ok = await svc.updateFabric(id, data);
                  }
      if (!mounted) return;
      if (ok) navigator.pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: const Text('Enregistrer'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  const _LabeledField({required this.label, required this.controller, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.grey)),
          ),
        )
      ],
    );
  }
}
