# (IT) Controllo copiature per CMS

## Utilizzo

Per fare il controllo copiature basta fare:
```
./check_plagiarism.sh
```

Lo script si aspetta che:
  * nalla cartella corrente esista una cartella `allsrc` con tutti i sorgenti.
  * il file JAR per JPLAG sia localizzato in `/opt/jplag/jplag.jar`
  * il binario di `sherlock` sia nel `PATH`

## Dipendenze:

Questo script ha le seguenti dipendenze:
  * docopts, `v0.6.1+fix`
    scaricabile da: https://github.com/docopt/docopts

  * sherlock
    scaricabile da: http://www.cs.usyd.edu.au/~scilect/sherlock/

  * JPLAG, `v2.11.X`
    scaricare il jar con le dipendenze da: https://github.com/jplag/jplag

## Procedimento dettagliato

Assumo che la cartella `allsrc`, contente i sorgenti estratti da CMS, sia nella cartella corrente. Gli output intermedi prodotti da questo script vengono salvato in una cartella che viene creata dallo script stesso.

1. Si controllano tutte le coppie di sorgenti con Sherlock con lo script `allpairs.rb`, l'output viene scritto in `allpairs.out`.

2. Si controlla una selezione dei sorgenti con JPLAG:
   a. lo script `tojplag.sh` seleziona un po' di sorgenti (facendo clustering con lo script `clustering.rb`) e li mette nella cartella `tojplag/` (che crea da solo)
   b. viene eseguito JPLAG sulla cartella `tojplag/`
```
   java -jar jplag.jar -m 100 -l c/c++ -r results tojplag
```
      i risultati intermedi vengono scritti in `jplag.log`.
   c. i risultati della similirità tra gruppi diversi calcolati da JPLAG vengono listati dallo script `list_groups.sh`

Il risulato finale è salvato come `plagiarism_report.txt`