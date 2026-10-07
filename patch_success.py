import re

path = 'mobile/lib/features/invite/invite_success_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'final String? targetPhone;',
    'final String? targetPhone;\n  final String? inviteToken;'
)

content = content.replace(
    'this.targetPhone,\n  });',
    'this.targetPhone,\n    this.inviteToken,\n  });'
)

content = content.replace(
    'initialRole: \'client\',',
    'initialRole: \'client\',\n                                inviteToken: inviteToken,'
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
