from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Keep the owner entry completely independent from school login.
s = s.replace("import 'school_setup.dart';", "import 'school_setup.dart';\nimport 'owner_console.dart';")
s = s.replace("hintText: '116936',\n        ", "")
s = s.replace(
    "Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerPanel(prefs: widget.prefs)));",
    "Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerConsole(prefs: widget.prefs)));"
)

p.write_text(s, encoding='utf-8')
