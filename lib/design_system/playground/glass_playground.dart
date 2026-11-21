import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../taro.dart';

/// Изолированный playground дизайн-системы Tarot Tree (Phase G1).
///
/// Проверяет все компоненты на фоне «мягких сумерек» (лавандовый +
/// пыльно-розовый + рассветное свечение) и позволяет переключать режим
/// рендеринга стекла для замеров производительности.
class GlassPlayground extends StatefulWidget {
  const GlassPlayground({super.key});

  @override
  State<GlassPlayground> createState() => _GlassPlaygroundState();
}

class _GlassPlaygroundState extends State<GlassPlayground> {
  TaroGlassMode _mode = TaroGlassMode.auto;
  int _segment = 0;
  int _dockIndex = 1;
  String _deck = 'Rider–Waite';
  bool _quietMode = false;
  double _voiceSpeed = 0.5;
  bool _micActive = false;
  String _selectedChip = 'Love & Relationships';
  final TextEditingController _input = TextEditingController();

  static const _decks = <String>[
    'Rider–Waite',
    'Marseille',
    'Thoth Obsidian',
    'Botanical',
    'Visconti–Sforza',
  ];

  static const _dock = <TaroDockItem>[
    TaroDockItem(icon: Icons.camera_alt_outlined, label: 'Camera'),
    TaroDockItem(icon: Icons.style_outlined, label: 'Table'),
    TaroDockItem(icon: Icons.menu_book_outlined, label: 'Almanac'),
    TaroDockItem(icon: Icons.auto_awesome_outlined, label: 'Astral'),
  ];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: TaroDuskBackground()),
          SafeArea(
            child: TaroGlassLayer(
              mode: _mode,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    const SizedBox(height: 20),
                    _modeSwitcher(),
                    const SizedBox(height: 24),
                    const TaroGlassSectionLabel(
                      eyebrow: 'Controls · Buttons',
                      title: 'TaroGlassButton',
                    ),
                    const SizedBox(height: 12),
                    _buttons(),
                    const SizedBox(height: 24),
                    const TaroGlassSectionLabel(
                      eyebrow: 'Controls · Segmented',
                      title: 'TaroGlassSegmentedControl',
                    ),
                    const SizedBox(height: 12),
                    TaroGlassSegmentedControl<int>(
                      segments: const [
                        TaroGlassSegment(value: 0, label: 'Standard'),
                        TaroGlassSegment(value: 1, label: 'Guided'),
                        TaroGlassSegment(value: 2, label: 'Live Oracle'),
                      ],
                      value: _segment,
                      onChanged: (v) => setState(() => _segment = v),
                    ),
                    const SizedBox(height: 24),
                    const TaroGlassSectionLabel(
                      eyebrow: 'Surfaces · Panel',
                      title: 'TaroGlassPanel',
                    ),
                    const SizedBox(height: 12),
                    _panel(),
                    const SizedBox(height: 24),
                    const TaroGlassSectionLabel(
                      eyebrow: 'Inputs · Field',
                      title: 'TaroGlassInput',
                    ),
                    const SizedBox(height: 12),
                    _inputs(),
                    const SizedBox(height: 24),
                    const TaroGlassSectionLabel(
                      eyebrow: 'Selectors · Deck',
                      title: 'TaroGlassSelect',
                    ),
                    const SizedBox(height: 12),
                    TaroGlassSelect<String>(
                      label: 'Deck',
                      value: _deck,
                      options: [
                        for (final d in _decks)
                          TaroSelectOption<String>(
                            value: d,
                            label: d,
                            subtitle: d == 'Rider–Waite'
                                ? '78 cards · classic'
                                : 'procedural back',
                          ),
                      ],
                      onChanged: (v) => setState(() => _deck = v),
                    ),
                    const SizedBox(height: 24),
                    const TaroGlassSectionLabel(
                      eyebrow: 'Navigation · Dock',
                      title: 'TaroGlassDock',
                    ),
                    const SizedBox(height: 12),
                    TaroGlassDock(
                      items: _dock,
                      index: _dockIndex,
                      onTap: (i) => setState(() => _dockIndex = i),
                    ),
                    const SizedBox(height: 24),
                    TaroGlassLayer(
                      mode: _mode,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const TaroGlassSectionLabel(
                            eyebrow: 'G3 Controls · Toggle / Slider / Icons',
                            title: 'Settings & Actions',
                          ),
                          const SizedBox(height: 12),
                          TaroGlassToggle(
                            label: 'Quiet guidance',
                            subtitle: 'Suppress movement beats during reading',
                            value: _quietMode,
                            onChanged: (v) => setState(() => _quietMode = v),
                          ),
                          const SizedBox(height: 14),
                          TaroGlassSlider(
                            label: 'Oracle voice cadence',
                            value: _voiceSpeed,
                            divisions: 10,
                            valueLabel:
                                '${(0.75 + _voiceSpeed * 0.5).toStringAsFixed(2)}x',
                            onChanged: (v) => setState(() => _voiceSpeed = v),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              TaroGlassIconButton(
                                icon: Icons.arrow_back,
                                tooltip: 'Back',
                                onPressed: () {},
                              ),
                              const SizedBox(width: 10),
                              TaroGlassIconButton(
                                icon: Icons.add,
                                tooltip: 'Add card',
                                onPressed: () {},
                              ),
                              const SizedBox(width: 10),
                              TaroGlassIconButton(
                                icon: Icons.mic_none,
                                tooltip: 'Voice input',
                                active: _micActive,
                                onPressed: () =>
                                    setState(() => _micActive = !_micActive),
                              ),
                              const SizedBox(width: 10),
                              TaroGlassIconButton(
                                icon: Icons.send_rounded,
                                tooltip: 'Send',
                                variant: TaroGlassButtonVariant.primary,
                                onPressed: () {},
                              ),
                              const Spacer(),
                              TaroGlassButton(
                                label: 'Open Sheet',
                                variant: TaroGlassButtonVariant.secondary,
                                onPressed: () => showTaroGlassSheet<void>(
                                  context: context,
                                  builder: (_) => const TaroGlassSheet(
                                    title: 'TaroGlassSheet',
                                    subtitle: 'UNIVERSAL GLASS BOTTOM SHEET',
                                    child: Text(
                                      'Shared glass sheet wrapper with drag '
                                      'handle, SafeArea and keyboard inset.',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          const TaroGlassSectionLabel(
                            eyebrow: 'G4 Controls · Chips / Pills / Progress',
                            title: 'TaroGlassChip & TaroGlassProgress',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final chip in const [
                                'Love & Relationships',
                                'Career & Path',
                                'Inner Crisis',
                              ])
                                TaroGlassChip(
                                  label: chip,
                                  selected: _selectedChip == chip,
                                  onTap: () =>
                                      setState(() => _selectedChip = chip),
                                ),
                              const TaroGlassPill(
                                label: 'PHYSICAL SYNC',
                                icon: Icons.photo_camera_front_outlined,
                                accent: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TaroGlassProgress(
                            label: 'SYNTHESIS PROGRESS',
                            value: _voiceSpeed,
                          ),
                          const SizedBox(height: 10),
                          const TaroGlassProgress(
                            label: 'WEAVING THE READING · · ·',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TAROT TREE',
          style: AppTypography.label(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            color: TaroColors.dawn,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Glass Design System',
          style: AppTypography.display(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: TaroColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'de-press.co direction · warm summer dawn after rain',
          style: AppTypography.body(
            fontSize: 13,
            color: TaroColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _modeSwitcher() {
    return TaroGlassSegmentedControl<TaroGlassMode>(
      segments: const [
        TaroGlassSegment(value: TaroGlassMode.auto, label: 'Auto'),
        TaroGlassSegment(value: TaroGlassMode.glass, label: 'Glass'),
        TaroGlassSegment(value: TaroGlassMode.fake, label: 'Fake'),
        TaroGlassSegment(value: TaroGlassMode.simple, label: 'Simple'),
        TaroGlassSegment(value: TaroGlassMode.opaque, label: 'Opaque'),
      ],
      value: _mode,
      onChanged: (v) => setState(() => _mode = v),
    );
  }

  Widget _buttons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TaroGlassButton(
                label: 'Primary',
                icon: Icons.auto_awesome,
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TaroGlassButton(
                label: 'Secondary',
                variant: TaroGlassButtonVariant.secondary,
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TaroGlassButton(
                label: 'Ghost',
                variant: TaroGlassButtonVariant.ghost,
                onPressed: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TaroGlassButton(
                label: 'Loading',
                loading: true,
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TaroGlassButton(
                label: 'Disabled',
                onPressed: null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _panel() {
    return TaroGlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Soft depth',
            style: AppTypography.heading(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: TaroColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Semi-transparent, rounded, softly glowing. Thin highlights and '
            'moderate refraction over a warm dusk backdrop.',
            style: AppTypography.body(
              fontSize: 13.5,
              height: 1.5,
              color: TaroColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputs() {
    return Column(
      children: [
        TaroGlassInput(
          label: 'Question',
          hint: 'What weighs on you?',
          controller: _input,
        ),
        const SizedBox(height: 12),
        TaroGlassInput(
          label: 'Email',
          hint: 'you@example.com',
          errorText: 'Please enter a valid email',
        ),
      ],
    );
  }
}
