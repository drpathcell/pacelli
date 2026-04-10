import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../shared/widgets/pacelli_ai_icon.dart';
import '../../data/ai_assistant_service.dart';

/// AI Assistant settings screen.
///
/// Streamlined flow: pick an AI provider → enter API key → connected.
/// Advanced MCP configuration is available in a collapsible section
/// at the bottom for power users.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  // Provider state
  AiProvider? _selectedProvider;
  final _apiKeyController = TextEditingController();
  bool _apiKeyObscured = true;
  bool _saving = false;
  bool _connected = false;

  // Advanced section
  bool _advancedExpanded = false;
  String? _token;
  bool _tokenLoading = false;
  late String _apiUrl;
  bool _apiUrlLoaded = false;
  bool _hostedMode = false;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedState() async {
    final url = await AiAssistantService.getApiUrl();
    final provider = await AiAssistantService.getSavedProvider();
    final hasKey = await AiAssistantService.hasApiKey();
    final hostedMode = await AiAssistantService.getHostedMode();
    if (mounted) {
      setState(() {
        _apiUrl = url;
        _apiUrlLoaded = true;
        _selectedProvider = provider;
        _connected = hasKey;
        _hostedMode = hostedMode;
      });
    }
  }

  Future<void> _connect() async {
    if (_selectedProvider == null || _apiKeyController.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await AiAssistantService.saveProviderConfig(
        provider: _selectedProvider!,
        apiKey: _apiKeyController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _saving = false;
          _connected = true;
        });
        context.showSnackBar(context.l10n.aiAssistantConnected);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        context.showSnackBar(context.l10n.aiAssistantConnectError, isError: true);
      }
    }
  }

  Future<void> _disconnect() async {
    await AiAssistantService.clearProviderConfig();
    if (mounted) {
      setState(() {
        _connected = false;
        _selectedProvider = null;
        _apiKeyController.clear();
      });
      context.showSnackBar(context.l10n.aiAssistantDisconnected);
    }
  }

  Future<void> _generateToken() async {
    setState(() => _tokenLoading = true);
    try {
      final token = await AiAssistantService.generateToken();
      if (mounted) {
        setState(() {
          _token = token;
          _tokenLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _tokenLoading = false);
        context.showSnackBar(context.l10n.aiAssistantTokenError, isError: true);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    context.showSnackBar(context.l10n.aiAssistantCopied(label));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aiAssistantTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Hero ──
          _HeroBanner(context: context),
          const SizedBox(height: 28),

          // ── Connected state ──
          if (_connected) ...[
            _ConnectedCard(
              provider: _selectedProvider,
              onDisconnect: _disconnect,
            ),
            const SizedBox(height: 24),
            _TipsSection(),
          ] else ...[
            // ── Provider picker ──
            Text(
              context.l10n.aiAssistantChooseProvider,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.aiAssistantChooseProviderDesc,
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...AiProvider.values.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ProviderCard(
                  provider: p,
                  selected: _selectedProvider == p,
                  onTap: () => setState(() => _selectedProvider = p),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── API key entry ──
            if (_selectedProvider != null) ...[
              Text(
                context.l10n.aiAssistantEnterApiKey(_selectedProvider!.displayName),
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.aiAssistantApiKeyDesc(_selectedProvider!.displayName),
                style: context.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                obscureText: _apiKeyObscured,
                decoration: InputDecoration(
                  hintText: _selectedProvider!.apiKeyHint,
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _apiKeyObscured
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _apiKeyObscured = !_apiKeyObscured),
                      ),
                    ],
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              _InfoBanner(
                text: context.l10n.aiAssistantApiKeySecure,
                icon: Icons.lock_rounded,
                color: context.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _apiKeyController.text.trim().isEmpty || _saving
                    ? null
                    : _connect,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.link_rounded, size: 18),
                label: Text(context.l10n.aiAssistantConnect),
              ),
              const SizedBox(height: 24),
            ],
          ],

          // ── Advanced section ──
          const Divider(),
          const SizedBox(height: 8),
          _AdvancedSection(
            expanded: _advancedExpanded,
            onToggle: () =>
                setState(() => _advancedExpanded = !_advancedExpanded),
            token: _token,
            tokenLoading: _tokenLoading,
            onGenerateToken: _generateToken,
            apiUrl: _apiUrlLoaded ? _apiUrl : '...',
            hostedMode: _hostedMode,
            onModeChanged: (v) {
              setState(() => _hostedMode = v);
              AiAssistantService.setHostedMode(v);
            },
            onCopy: _copyToClipboard,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────

/// Supported AI providers.
enum AiProvider {
  claude(
    displayName: 'Claude',
    description: 'By Anthropic. Best for nuanced reasoning and long tasks.',
    apiKeyHint: 'sk-ant-...',
    iconColor: Color(0xFFD97757),
    iconLetter: 'C',
  ),
  gemini(
    displayName: 'Gemini',
    description: 'By Google. Great for search-powered answers.',
    apiKeyHint: 'AIza...',
    iconColor: Color(0xFF4285F4),
    iconLetter: 'G',
  ),
  chatGpt(
    displayName: 'ChatGPT',
    description: 'By OpenAI. Popular general-purpose assistant.',
    apiKeyHint: 'sk-...',
    iconColor: Color(0xFF10A37F),
    iconLetter: 'O',
  );

  const AiProvider({
    required this.displayName,
    required this.description,
    required this.apiKeyHint,
    required this.iconColor,
    required this.iconLetter,
  });

  final String displayName;
  final String description;
  final String apiKeyHint;
  final Color iconColor;
  final String iconLetter;
}

// ── Private Widgets ──────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final BuildContext context;
  const _HeroBanner({required this.context});

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colorScheme.primary.withValues(alpha: 0.08),
            context.colorScheme.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: PacelliAiIcon(
              size: 32,
              color: context.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.aiAssistantHeroTitle,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.aiAssistantHeroSubtitle,
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final AiProvider provider;
  final bool selected;
  final VoidCallback onTap;

  const _ProviderCard({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? provider.iconColor
                : context.colorScheme.outline.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
          color: selected
              ? provider.iconColor.withValues(alpha: 0.06)
              : context.colorScheme.surface,
        ),
        child: Row(
          children: [
            // Provider icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: provider.iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                provider.iconLetter,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: provider.iconColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.displayName,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.description,
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: provider.iconColor, size: 24),
          ],
        ),
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  final AiProvider? provider;
  final VoidCallback onDisconnect;

  const _ConnectedCard({
    required this.provider,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded,
                    color: Colors.green.shade700, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.aiAssistantStatusConnected,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800,
                      ),
                    ),
                    if (provider != null)
                      Text(
                        context.l10n.aiAssistantConnectedTo(provider!.displayName),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: Colors.green.shade700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDisconnect,
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: Text(context.l10n.aiAssistantDisconnect),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                side: BorderSide(color: Colors.red.shade300),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _InfoBanner({required this.text, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 18, color: context.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n.aiAssistantTipsTitle,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TipItem(text: context.l10n.aiAssistantTip2),
          _TipItem(text: context.l10n.aiAssistantTip3),
        ],
      ),
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final String? token;
  final bool tokenLoading;
  final VoidCallback onGenerateToken;
  final String apiUrl;
  final bool hostedMode;
  final ValueChanged<bool> onModeChanged;
  final void Function(String text, String label) onCopy;

  const _AdvancedSection({
    required this.expanded,
    required this.onToggle,
    required this.token,
    required this.tokenLoading,
    required this.onGenerateToken,
    required this.apiUrl,
    required this.hostedMode,
    required this.onModeChanged,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.build_rounded,
                    size: 18, color: context.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  context.l10n.aiAssistantAdvancedTitle,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          Text(
            context.l10n.aiAssistantAdvancedDesc,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Token generation
          _SectionHeader(
            icon: Icons.key_rounded,
            title: context.l10n.aiAssistantStep1Title,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.aiAssistantStep1Desc,
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: tokenLoading ? null : onGenerateToken,
            icon: tokenLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              token == null
                  ? context.l10n.aiAssistantGenerateToken
                  : context.l10n.aiAssistantRegenerateToken,
            ),
          ),
          if (token != null) ...[
            const SizedBox(height: 12),
            _CopyableField(
              label: context.l10n.aiAssistantTokenLabel,
              value: token!,
              obscure: true,
              onCopy: () => onCopy(token!, context.l10n.aiAssistantTokenLabel),
            ),
          ],
          const SizedBox(height: 20),

          // API URL
          _SectionHeader(
            icon: Icons.cloud_outlined,
            title: context.l10n.aiAssistantStep2Title,
          ),
          const SizedBox(height: 8),
          _CopyableField(
            label: context.l10n.aiAssistantApiUrlLabel,
            value: apiUrl,
            onCopy: () =>
                onCopy(apiUrl, context.l10n.aiAssistantApiUrlLabel),
          ),
          const SizedBox(height: 20),

          // Connection mode
          _SectionHeader(
            icon: Icons.settings_ethernet_rounded,
            title: context.l10n.aiAssistantConnectionMode,
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(context.l10n.aiAssistantModeLocal),
                icon: const Icon(Icons.computer_rounded, size: 16),
              ),
              ButtonSegment(
                value: true,
                label: Text(context.l10n.aiAssistantModeHosted),
                icon: const Icon(Icons.cloud_rounded, size: 16),
              ),
            ],
            selected: {hostedMode},
            onSelectionChanged: (v) => onModeChanged(v.first),
          ),
          const SizedBox(height: 16),

          // MCP config block
          _SectionHeader(
            icon: Icons.terminal_rounded,
            title: context.l10n.aiAssistantStep3Title,
          ),
          const SizedBox(height: 8),
          _ConfigBlock(
            apiUrl: apiUrl,
            token: token ?? 'YOUR_TOKEN_HERE',
            hostedMode: hostedMode,
            onCopy: () {
              final config = hostedMode
                  ? _buildHostedConfigJson(token ?? 'YOUR_TOKEN_HERE')
                  : _buildConfigJson(apiUrl, token ?? 'YOUR_TOKEN_HERE');
              onCopy(config, context.l10n.aiAssistantConfig);
            },
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CopyableField extends StatelessWidget {
  final String label;
  final String value;
  final bool obscure;
  final VoidCallback onCopy;

  const _CopyableField({
    required this.label,
    required this.value,
    this.obscure = false,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = obscure && value.length > 20
        ? '${value.substring(0, 12)}${'•' * 20}${value.substring(value.length - 8)}'
        : value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayValue,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: onCopy,
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ConfigBlock extends StatelessWidget {
  final String apiUrl;
  final String token;
  final bool hostedMode;
  final VoidCallback onCopy;

  const _ConfigBlock({
    required this.apiUrl,
    required this.token,
    this.hostedMode = false,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'mcp_config.json',
                  style: TextStyle(
                    color: Color(0xFF9CDCFE),
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onCopy,
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: Color(0xFF808080),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              hostedMode
                  ? _buildHostedConfigJson(token)
                  : _buildConfigJson(apiUrl, token),
              style: const TextStyle(
                color: Color(0xFFD4D4D4),
                fontSize: 13,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;
  const _TipItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ',
              style: TextStyle(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text, style: context.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// ── Config Builders ──────────────────────────────────────────────

String _buildConfigJson(String apiUrl, String token) {
  return '''{
  "mcpServers": {
    "pacelli": {
      "command": "node",
      "args": [
        "/path/to/pacelli/mcp-server/dist/index.js"
      ],
      "env": {
        "PACELLI_API_URL": "$apiUrl",
        "PACELLI_AUTH_TOKEN": "$token"
      }
    }
  }
}''';
}

String _buildHostedConfigJson(String token) {
  return '''{
  "mcpServers": {
    "pacelli": {
      "type": "streamable-http",
      "url": "https://pacelli-mcp-XXXXX.run.app/mcp",
      "headers": {
        "Authorization": "Bearer $token"
      }
    }
  }
}''';
}
