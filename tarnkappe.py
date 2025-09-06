import feedparser
import subprocess
import sys

# RSS-Feed-URL
feed_url = "https://tarnkappe.info/feed"

# Den RSS-Feed herunterladen und parsen
feed = feedparser.parse(feed_url)

# Den ersten Artikel aus dem Feed extrahieren
if feed.entries:
    first_article = feed.entries[0]
    title = first_article.title
    link = first_article.link
    description = first_article.description

    # Ausgabe der Werte an die Standardausgabe
    print(title)
    print(link)
    print(description)
else:
    print("Es konnte kein Artikel gefunden werden.")

# Den Python-Prozess beenden und die Werte an die Bash-Umgebung übergeben
sys.stdout.flush()
