import re

path = 'mobile/lib/features/auth/register_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'final String? initialPhone;',
    'final String? initialPhone;\n  final String? inviteToken;'
)

content = content.replace(
    'this.initialPhone,\n  });',
    'this.initialPhone,\n    this.inviteToken,\n  });'
)

content = content.replace(
    'role: widget.initialRole,\n        );',
    'role: widget.initialRole,\n          inviteToken: widget.inviteToken,\n        );'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
