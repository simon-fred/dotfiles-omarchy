# USB-webcam bandbreddsfix

Tystar "myrornas krig" (statiskt brus) från USB UVC-webcams som rapporterar
fel bandbreddsdescriptor — t.ex. en Logitech C270 (USB-ID `046d:0825`) i en
dock.

## Problem

Vissa UVC-kameror skickar en felaktig USB-bandbreddsdescriptor till kärnan.
När `uvcvideo` litar på det värdet får kameran för lite (eller fel typ av)
USB-bandwidth allokerad, och bilden blir statiskt brus istället för video.
Det syns oftast tydligast på kameror som sitter bakom en USB-hub eller dock.

## Vad paketet gör

`install.sh` är idempotent och utför:

1. Skriver `/etc/modprobe.d/uvcvideo-quirks.conf` med
   `options uvcvideo quirks=128`. Värdet `128` är `UVC_QUIRK_FIX_BANDWIDTH`,
   som får kärnan att räkna ut bandbredden från format och framerate
   istället för att lita på enhetens egen rapport.
2. Laddar om `uvcvideo`-modulen så ändringen tar effekt utan reboot.
3. Verifierar att `/sys/module/uvcvideo/parameters/quirks` är `128`.

## Installation

```bash
sudo ./install.sh
```

(Skriptet sudo:ar om sig självt om du glömmer.)

Notera: om någon app (webbläsare, kamera-app) använder webcamen just nu
misslyckas modul-reload. Stäng dem och kör igen, eller reboota.

## Testa att det funkar

Anslut USB-webcamen och öppna t.ex.:

- https://webcamtests.com/ i Zen/Chromium, eller
- `mpv av://v4l2:/dev/video4` i terminal (byt video-nummer vid behov;
  `v4l2-ctl --list-devices` listar alla kameror).

Bilden ska vara stabil — inte myror.

Den integrerade kameran ska fortsätta fungera som vanligt. Quirken är global
över alla UVC-enheter men är godartad för kameror som inte behöver den.

## Avinstallation

```bash
sudo ./install.sh --uninstall
```

Tar bort modprobe-filen och laddar om modulen så `quirks` återgår till `0`.

## När hjälper detta inte?

Om bilden fortfarande är myror efter installation är det troligen inte ett
bandbreddsproblem utan en format-förhandlingsbugg i appen — typiskt att
WebRTC i webbläsaren faller tillbaka till YUYV när MJPG vore rätt val. Då
är nästa steg någon kombination av:

- Tvinga MJPG i webbläsaren (Chromium: `chrome://flags`, leta efter
  experiment relaterade till video-capture).
- Testa kameran utanför webbläsaren först (`mpv av://v4l2:...`) för att
  isolera om felet är i kärnan eller i appen.

## Källor

- [Linux kernel uvcvideo quirks](https://docs.kernel.org/admin-guide/media/uvcvideo.html)
  — listan över definierade quirks-bitar.
- Arch Wiki: [Webcam setup](https://wiki.archlinux.org/title/Webcam_setup)
  — refererar `quirks=128` som standardlösning för Logitech-kameror med
  bandbreddsproblem.
