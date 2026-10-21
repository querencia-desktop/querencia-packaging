# Entfernt KI-Abschnitte aus installierter Doku (Vorgabe des Besitzers,
# 21.10.2026, CLEAN-1 Nachtrag 2); der Quelltext der Repos bleibt unverändert.
#   README.md:  Überschrift „KI-Hinweis“ (jede Ebene) bis zur nächsten
#               Überschrift gleicher oder höherer Ebene
#   COPYRIGHT:  Absatz, der mit „KI-Hinweis:“ beginnt, bis zur Leerzeile
#               (mit der folgenden Leerzeile)
#   Verweis „Urheber- und KI-Hinweis in …“ wird zu „Urheberhinweis in …“
# Aufruf: awk -f ki-abschnitt-entfernen.awk <datei> >ziel
/^#+[ \t]+KI-Hinweis[ \t]*$/ {
    match($0, /^#+/); ebene = RLENGTH; weg = 1; next
}
weg == 1 && /^#+[ \t]/ {
    match($0, /^#+/); if (RLENGTH <= ebene) weg = 0
}
weg == 1 { next }
/^KI-Hinweis:/ { absatz = 1; next }
absatz == 1 && /^[ \t]*$/ { absatz = 0; next }
absatz == 1 { next }
{ gsub(/Urheber- und KI-Hinweis/, "Urheberhinweis"); print }
