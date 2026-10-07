import re
import os

base_dir = "mobile"

def patch_file(path, replacements):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
        
# Fix 1: mrcoach_landing_screen.dart:9:16 - unused _openWhatsApp
patch_file(f"{base_dir}/lib/features/landing/mrcoach_landing_screen.dart", [
    ("void _openWhatsApp() async {", "// void _openWhatsApp() async {")
])

# Fix 2: subscription_screen.dart:531:11 - unused isStudio
patch_file(f"{base_dir}/lib/features/subscription/subscription_screen.dart", [
    ("bool isStudio = widget.planId == 'studio';", "// bool isStudio = widget.planId == 'studio';")
])

# Fix 3: trainer_business_screen.dart:284:8 - unused _showSubscriptionDetailsModal
patch_file(f"{base_dir}/lib/features/trainer/presentation/screens/trainer_business_screen.dart", [
    ("void _showSubscriptionDetailsModal() {", "// void _showSubscriptionDetailsModal() {")
])

# Fix 4: trainer_business_screen.dart:743:12 - override_on_non_overriding_member
patch_file(f"{base_dir}/lib/features/trainer/presentation/screens/trainer_business_screen.dart", [
    ("  @override\n  void dispose() {\n    super.dispose();\n  }", "  // @override\n  // void dispose() {\n  //   super.dispose();\n  // }")
])

# Fix 5: trainer_profile_setup_screen.dart:30:8 - unused _isLoading
patch_file(f"{base_dir}/lib/features/trainer/presentation/screens/trainer_profile_setup_screen.dart", [
    ("bool _isLoading = false;", "// bool _isLoading = false;")
])

# Fix 6: trainer_students_screen.dart:28:10 - unused _errorMessage
patch_file(f"{base_dir}/lib/features/trainer/trainer_students_screen.dart", [
    ("String? _errorMessage;", "// String? _errorMessage;")
])

print("Lints patched.")
