import re

path = 'mobile/lib/features/invite/invite_landing_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

new_state = '''
  bool _isLoading = true;
  String _trainerName = 'Carregando...';
  String? _targetEmail;
  String? _targetPhone;

  @override
  void initState() {
    super.initState();
    _fetchTrainerData();
  }

  Future<void> _fetchTrainerData() async {
    try {
      final res = await InviteService.validateInvite(widget.token);
      if (mounted) {
        setState(() {
          _trainerName = res['trainer_name'] ?? 'Seu Personal Trainer';
          _targetEmail = res['target_email'];
          _targetPhone = res['target_phone'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Se der erro, mostra erro e esconde botão
        setState(() {
          _trainerName = 'Convite inválido ou expirado';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: const Text(
              'Este convite não é mais válido.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }
  }

  bool _isConsuming = false;

  Future<void> _acceptInvite() async {
    if (_trainerName == 'Convite inválido ou expirado') return;
    if (_isConsuming) return;
    setState(() => _isConsuming = true);

    try {
      // Agora não consumimos aqui! Apenas avançamos.
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InviteSuccessScreen(
              trainerName: _trainerName,
              targetEmail: _targetEmail,
              targetPhone: _targetPhone,
              inviteToken: widget.token,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConsuming = false);
      }
    }
  }
'''

content = re.sub(r'bool _isLoading = true;.*?    \} catch \(e\) \{.*?    \} finally \{.*?    \}\n  \}', new_state, content, flags=re.DOTALL)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
