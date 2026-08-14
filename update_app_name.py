import os

REPLACEMENTS = {
    "Team N Makeovers": "Team N ERP",
    "TEAM N MAKEOVERS": "TEAM N ERP",
    "Team N CRM": "Team N ERP",
    "TEAM N CRM": "TEAM N ERP",
    "Nizan Crm": "Team N ERP",
    "Nizan CRM": "Team N ERP",
    "Team N\\nMakeovers": "Team N\\nERP",
}

def walk_and_replace(directory):
    for root, dirs, files in os.walk(directory):
        if '.git' in dirs:
            dirs.remove('.git')
        if 'build' in dirs:
            dirs.remove('build')
        for file in files:
            if file.endswith(('.dart', '.xml', '.plist', '.html', '.yaml', '.md', '.pbxproj', '.xcconfig', '.js', '.json')):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    new_content = content
                    for old, new in REPLACEMENTS.items():
                        new_content = new_content.replace(old, new)
                    
                    # specific replacement for android manifest android:label="Team N"
                    if file == "AndroidManifest.xml" and 'android:label="Team N"' in new_content:
                        new_content = new_content.replace('android:label="Team N"', 'android:label="Team N ERP"')
                    
                    # specific replacement for lib/main.dart title: 'Team N '
                    if file == "main.dart" and "title: 'Team N '" in new_content:
                        new_content = new_content.replace("title: 'Team N '", "title: 'Team N ERP'")
                        
                    # specific replacement for web/index.html title >Team N<
                    if file == "index.html" and "<title>Team N</title>" in new_content:
                        new_content = new_content.replace("<title>Team N</title>", "<title>Team N ERP</title>")
                    if file == "index.html" and 'apple-mobile-web-app-title" content="Team N"' in new_content:
                        new_content = new_content.replace('apple-mobile-web-app-title" content="Team N"', 'apple-mobile-web-app-title" content="Team N ERP"')

                    if new_content != content:
                        with open(filepath, 'w', encoding='utf-8') as f:
                            f.write(new_content)
                        print(f"Updated: {filepath}")
                except Exception as e:
                    print(f"Error reading {filepath}: {e}")

walk_and_replace('.')
print("Done")
