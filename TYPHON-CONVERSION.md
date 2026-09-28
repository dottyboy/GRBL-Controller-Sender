# Typhon konverzija

Ovo je CodeTyphon (Qt5) verzija projekta. Originalna Lazarus verzija ostaje
netaknuta u `LAZARUS-DEVELOPMENT/GRBL-Controller-Sender` — ovo je kopija, ne
premještanje.

Isključeno iz kopije (nije trebalo za build): `References/` (920 MB tuđih
klonova), `tools/`, stari `lib/`, `backup/`, te build-artefakti (`.o`,
`.ppu`, `.res`, `.dbg`, `.lps`, staru izvršnu datoteku).

## Otvaranje u IDE-u

```
QT_QPA_PLATFORMTHEME=qt5ct typhon-ide64 GRBL-Controller-Sender.ctpr
```

ili prečac `typhon64.desktop` na Desktopu, pa File → Open Project.

## Build iz terminala

```
typhonbuild -B --ws=qt5 GRBL-Controller-Sender.ctpr
```

(prvi put treba i `typhonbuild -B --ws=qt5 packages/TLazSerial/LazSerialPort.ctpkg`
da se ugniježđeni paket kompajlira — nakon toga IDE ga pamti.)

## Što je promijenjeno pri konverziji

- `.lpi` → `.ctpr`, `.lpr` → `.ppr`, sve `.lfm` → `.frm` (CodeTyphon koristi
  drugu ekstenziju za forme; sadržaj je identičan tekstualni format).
- Nazivi paketa u `RequiredPackages`: `LCL`→`adLCL`+`adLCLBase`,
  `SynEdit`→`bs_SynEdit`, `LazOpenGLContext`→`lz_OpenGL`. `LazSerialPort`
  (projektni paket u `packages/TLazSerial`) ostaje pod istim imenom, samo
  `.lpk`→`.ctpkg` i njegov `RequiredPkgs` prilagođen (`LCL`→`adLCLBase`,
  `FCL`→`adFCL`, `IDEIntf`→`bs_IDEIntf`).
- U `packages/TLazSerial/lazserial.pas` i `lazserialsetup.pas` uklonjen
  zastarjeli `LazarusResources.Add` / `{$i *.lrs}` mehanizam za ikonu
  komponente — moderni LCL više ne izvozi `LazarusResources`. Komponenta
  radi identično, samo bez prilagođene ikone u paleti. `lazserialsetup.pas`
  sad koristi `{$R *.frm}` kao i sve ostale forme.

## Usput pronađena greška (ne CodeTyphon-specifična)

`src/core/uboardcatalog.pas`: `Catalog` je bio deklariran kao fiksni
`array[0..47] of TBoardProfile`, a `BoardCatalog` ga vraća kao
`TBoardProfileArray` (dinamički niz) — FPC to odbija ("Incompatible types").
Ispravljeno na `Catalog: TBoardProfileArray = (...)`. Ista greška postoji
i u Lazarus originalu (nisam ga dirao) — vjerojatno projekt dosad nije bio
stvarno kompajliran ni u Lazarusu, jer bi ista greška pukla i tamo.

## Testirano

- `typhonbuild -B --ws=qt5` na paketu i projektu: čist build (samo hintovi/
  upozorenja, bez grešaka).
- Pokretanje izvršne datoteke: proces ostaje živ, log bez iznimki.

Nije testirano: ponašanje u GUI-ju (serijski port, jog, G-code parsing) —
to treba provjeriti uživo.
