from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Final release patch: the owner console is completely independent
# from the school's email/password login and never exposes the owner PIN.
owner_import = "import 'owner_console.dart';"
if owner_import not in s:
    s = s.replace("import 'school_setup.dart';", "import 'school_setup.dart';\n" + owner_import)

# Never show the real owner PIN as a hint/placeholder.
s = s.replace("hintText: '116936',\n        ", "")
s = s.replace("hintText: \"116936\",\n        ", "")

# Three taps on Adreemk open the standalone owner console after PIN validation.
old_route = "Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerPanel(prefs: widget.prefs)));"
new_route = "Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerConsole(prefs: widget.prefs)));"
s = s.replace(old_route, new_route)

# Do not silently ship an unpatched APK.
if owner_import not in s:
    raise SystemExit('OWNER RELEASE PATCH FAILED: owner_console import missing')
if new_route not in s:
    raise SystemExit('OWNER RELEASE PATCH FAILED: standalone owner route missing')
if "hintText: '116936'" in s or 'hintText: "116936"' in s:
    raise SystemExit('OWNER RELEASE PATCH FAILED: owner PIN is still visible in hintText')

p.write_text(s, encoding='utf-8')
print('Owner release patch verified.')
