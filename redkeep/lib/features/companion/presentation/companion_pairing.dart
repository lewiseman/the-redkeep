import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/companion_protocol.dart';

class VerifyComputerDialog extends StatefulWidget {
  const VerifyComputerDialog({super.key, required this.code});
  final PairingCode code;
  @override
  State<VerifyComputerDialog> createState() => VerifyComputerDialogState();
}

class VerifyComputerDialogState extends State<VerifyComputerDialog> {
  final name = TextEditingController(text: 'My Redkeep phone');
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.verified_user_outlined, size: 32),
    title: const Text('Is this your computer?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.computer_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.code.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Check this identity in Journal Companion. Continue only if it matches.',
          ),
          const SizedBox(height: 8),
          SelectableText(
            widget.code.pin,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: name,
            maxLength: 48,
            decoration: const InputDecoration(labelText: 'Name for this phone'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('companion-confirm-identity'),
        onPressed: () => Navigator.pop(context, name.text),
        child: const Text('It matches · continue'),
      ),
    ],
  );
}

class PasteCodeDialog extends StatefulWidget {
  const PasteCodeDialog({super.key});
  @override
  State<PasteCodeDialog> createState() => PasteCodeDialogState();
}

class PasteCodeDialogState extends State<PasteCodeDialog> {
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.content_paste_rounded, size: 32),
    title: const Text('Use a code'),
    content: TextField(
      controller: code,
      maxLines: 6,
      maxLength: 8192,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      decoration: const InputDecoration(
        labelText: 'Full computer code',
        hintText:
            'Copy the full pairing code shown below the QR on your computer.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, code.text),
        child: const Text('Continue'),
      ),
    ],
  );
}

class CompanionScannerPage extends StatefulWidget {
  const CompanionScannerPage({super.key});
  @override
  State<CompanionScannerPage> createState() => _CompanionScannerPageState();
}

class CompanionScanResult {
  const CompanionScanResult({this.raw, this.useCode = false});
  final String? raw;
  final bool useCode;
}

class _CompanionScannerPageState extends State<CompanionScannerPage> {
  final controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool captured = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan QR')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Row(
            children: [
              Icon(Icons.laptop_mac_rounded, size: 32),
              SizedBox(width: 16),
              Expanded(child: Text('Point at the QR on your computer.')),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  final raw = capture.barcodes.firstOrNull?.rawValue;
                  if (captured || raw == null) return;
                  captured = true;
                  Navigator.pop(context, CompanionScanResult(raw: raw));
                },
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.no_photography_outlined, size: 56),
                        const SizedBox(height: 16),
                        const Text(
                          'Camera unavailable. Allow Camera in Settings, or use the computer’s code.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const IgnorePointer(
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: .72,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.white70, width: 3),
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton.icon(
              onPressed: () => Navigator.pop(
                context,
                const CompanionScanResult(useCode: true),
              ),
              icon: const Icon(Icons.content_paste_rounded),
              label: const Text('Use a code instead'),
            ),
          ),
        ),
      ],
    ),
  );
}
