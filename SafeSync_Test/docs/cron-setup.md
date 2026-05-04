# SafeSync – Cron-Automatisierung (Kriterium d)

## Ziel
SafeSync soll alle 60 Minuten automatisch im Hintergrund laufen, ohne manuellen Eingriff.

## Crontab-Eintrag einrichten

1. Crontab öffnen:
```bash
crontab -e
```

2. Folgenden Eintrag hinzufügen (Pfad anpassen):
```
0 * * * * /absoluter/pfad/zu/SafeSync_Test/main.sh >> /absoluter/pfad/zu/SafeSync_Test/data/safesync.log 2>&1
```

Beispiel (wenn SafeSync unter `/home/user/Currency-Tracker/SafeSync_Test` liegt):
```
0 * * * * /home/user/Currency-Tracker/SafeSync_Test/main.sh >> /home/user/Currency-Tracker/SafeSync_Test/data/safesync.log 2>&1
```

3. Crontab speichern und beenden.

## Erklärung der Cron-Syntax

```
0 * * * *
│ │ │ │ │
│ │ │ │ └── Wochentag (0–7, 0/7 = Sonntag)
│ │ │ └──── Monat (1–12)
│ │ └────── Tag im Monat (1–31)
│ └──────── Stunde (0–23)
└────────── Minute (0 = zur vollen Stunde)
```

`0 * * * *` = jede Stunde, zur Minute 0 (00:00, 01:00, 02:00, ...)

## Cron-Einträge prüfen

```bash
crontab -l
```

## Logs prüfen

```bash
tail -f SafeSync_Test/data/safesync.log
```

## Cron-Job entfernen

```bash
crontab -e
# Eintrag löschen, speichern und beenden
```
