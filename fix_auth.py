import re

path = 'mobile/lib/services/auth_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the block inside signIn
bad_block = """      if (response.user != null) {
        await _ensureProfileUpserted(response.user!);
      }
      if (inviteToken != null && inviteToken.isNotEmpty) {
        try {
          await InviteService.consumeInvite(inviteToken);
        } catch (e) {
          debugPrint("Erro ao consumir convite: $e");
        }
      }
      return response;"""

good_block = """      if (response.user != null) {
        await _ensureProfileUpserted(response.user!);
      }
      return response;"""

# Only replace the first occurrence (which is in signIn)
content = content.replace(bad_block, good_block, 1)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
