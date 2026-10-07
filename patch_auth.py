import re

path = 'mobile/lib/services/auth_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'professionalDocument, // Ex: \'CREF 019284-G/SP\', \'CBMF-10294\', \'123.456.789-00\'\n  }) async {',
    'professionalDocument, // Ex: \'CREF 019284-G/SP\', \'CBMF-10294\', \'123.456.789-00\'\n    String? inviteToken,\n  }) async {'
)

content = content.replace(
    'await _ensureProfileUpserted(response.user!);\n      }\n      return response;',
    'await _ensureProfileUpserted(response.user!);\n      }\n      if (inviteToken != null && inviteToken.isNotEmpty) {\n        try {\n          await InviteService.consumeInvite(inviteToken);\n        } catch (e) {\n          debugPrint("Erro ao consumir convite: $e");\n        }\n      }\n      return response;'
)

content = content.replace(
    'return await signIn(email: email, password: password);\n        } catch (backendErr) {',
    'final authRes = await signIn(email: email, password: password);\n          if (inviteToken != null && inviteToken.isNotEmpty) {\n            try {\n              await InviteService.consumeInvite(inviteToken);\n            } catch (e) {\n              debugPrint("Erro ao consumir convite fallback: $e");\n            }\n          }\n          return authRes;\n        } catch (backendErr) {'
)

if 'import \'invite_service.dart\';' not in content:
    content = content.replace('import \'../core/config/app_config.dart\';', 'import \'../core/config/app_config.dart\';\nimport \'invite_service.dart\';')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
