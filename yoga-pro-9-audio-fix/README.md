# Yoga Pro 9 16IMH9 — högtalar-fix

Aktiverar bas- och mellanregisterhögtalarna på Lenovo Yoga Pro 9 16IMH9 (Gen 9,
Intel Meteor Lake) under Linux. Utan denna fix låter ljudet "tomt" / tunt
eftersom endast diskanthögtalarna får signal.

## Problem

Laptopen har sex högtalare drivna av två extra effektförstärkar-chip
(TI TAS2781) som sitter på I2C-bussen — inte på HDA-bussen. Linux-kärnan har
ingen färdig quirk för denna SSID (`17aa38d5`), så förstärkarna förblir
avstängda och bara tweetrarna hörs.

Detta är ett känt problem som löses upstream gradvis. Tills dess används en
direkt I2C-konfiguration som "knackar" på amparna och slår på dem manuellt.

## Vad paketet gör

`install.sh` är idempotent och utför:

1. Verifierar att maskinen är en Yoga Pro 9 16IMH9 (annars avbryts).
2. Installerar `i2c-tools` via pacman om det saknas.
3. Skriver `/usr/local/bin/2pa-byps.sh` — själva I2C-konfigurations-skriptet
   från [maximmaxim345/yoga_pro_9i_gen9_linux](https://github.com/maximmaxim345/yoga_pro_9i_gen9_linux)
   (inlinead för full reproducerbarhet).
4. Skriver `/etc/systemd/system/yoga-16imh9-speakers.service` som kör skriptet
   vid boot och efter resume.
5. Skriver `/etc/modprobe.d/yoga-speakers.conf` som blacklistar
   `snd_hda_scodec_tas2781_i2c` (kärnans driver ska inte krocka med vårt
   skript).
6. Tar bort ev. äldre `/etc/udev/rules.d/99-i2c-power-control.rules` från
   tidigare workaround-försök.
7. `systemctl daemon-reload && systemctl enable --now ...`.
8. Kör skriptet manuellt en gång som smoke-test.

## Installation

```bash
sudo ./install.sh
```

(Skriptet sudo:ar om sig självt om du glömmer.)

## Testa att det funkar

Efter installationen:

```bash
speaker-test -c 2 -t wav -l 1
```

Eller spela en låt med tydlig bas. Ljudet ska nu vara fylligt, inte "tomt".

Kontrollera service-status:

```bash
systemctl status yoga-16imh9-speakers.service
```

En `oneshot`-service går till `inactive (dead)` med `Result=success` efter att
ha kört klart — det är förväntat.

## Suspend/resume

Servicen är kopplad till `sleep.target` så den körs om automatiskt när du
väcker datorn. Om basen försvinner efter suspend, kör manuellt:

```bash
sudo systemctl start yoga-16imh9-speakers.service
```

…och rapportera, för då kanske triggern behöver justeras.

## Avinstallation

```bash
sudo ./install.sh --uninstall
```

Tar bort `2pa-byps.sh`, service-filen, modprobe-blacklisten och inaktiverar
servicen. Reboota för att kärnan ska få ladda den tidigare blacklistade
modulen igen.

## När kan jag ta bort detta?

När Linux-kärnan får upstream-stöd för SSID `17aa38d5` (Yoga Pro 9 16IMH9)
behövs inte längre denna workaround. Indikatorer:

- `lsmod | grep tas2781` visar att modulen laddas (efter att blacklisten
  tagits bort)
- Du hör fyllig bas efter ren installation utan denna fix
- [Upstream-repot](https://github.com/maximmaxim345/yoga_pro_9i_gen9_linux)
  noterar att fixet inte längre behövs

Kör då `sudo ./install.sh --uninstall` och reboota.

## Risker / varningar

- **Skriver direkt till I2C-register på amp-chippen som root.** Detta är
  inte farligt så länge det körs på rätt hårdvara — därför sanity-checkar
  installern att modellen verkligen är `Yoga Pro 9 16IMH9` innan något
  skrivs.
- BIOS-uppdateringar kan teoretiskt ändra I2C-layouten. Om ljudet plötsligt
  blir trasigt efter en BIOS-uppgradering, kolla
  [upstream-repot](https://github.com/maximmaxim345/yoga_pro_9i_gen9_linux)
  för en uppdaterad version av `2pa-byps.sh` och uppdatera den inlinade
  versionen i `install.sh` om så behövs.

## Källor

- [maximmaxim345/yoga_pro_9i_gen9_linux](https://github.com/maximmaxim345/yoga_pro_9i_gen9_linux)
  — huvudkällan, README med inlinead skriptversion (senast uppdaterad
  juli 2025).
- [karypid/YogaPro-16IMH9](https://github.com/karypid/YogaPro-16IMH9)
  — bekräftar fixet för exakt denna modell.
- [kernel.org bugzilla #217449](https://bugzilla.kernel.org/show_bug.cgi?id=217449)
  — upstream-tracking av buggen.
