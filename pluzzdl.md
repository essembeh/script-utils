# Outil pour télécharger les vidéos de Pluzz

Ce script permet de télécharger les vidéos disponibles sur Pluzz afin de les regarder *librement* sous Linux.

J'ai développé ce script afin que mon fils puisse regarder ses dessins-animés avec des logiciels libres sous Linux.
Car le site Pluzz utilise Flash de Adobe, logiciel non libre afin de lire les vidéos, et je n'installe pas sous Linux.
Au passage je trouve dommage que Pluzz qui fait partie de France Télévision ne mette pas en avant des formats libres ou ouverts.

Par contre Pluzz! fonctionne sous iOS et pourtant il n'y a pas Flash sous iOS. 
Il se trouve que tout le contenu est disponible dans un format MPG pour les appareils iOS, cependant le reste du monde semble contraint à devoir utiliser Flash...

Donc ce script permet de récupérer les contenus mis à disposition pour les équipements ne supportant pas Flash.


## Dependances

Ce script utilise les commandes linux standards *wget*, *unzip*, *grep* ...

La seule dépendance importante est *jq* (site du projet: http://stedolan.github.io/jq/).

Si *jq* n'est pas trouvé dans le PATH, alors il faut le télécharger et le mettre ou dans le PATH ou dans *~/.pluzzdl/lib/*

Ce script n'utilise pas *vlc* ou *mplayer* pour récupérer la vidéo, mais seulement *wget*.


## Installation

Pour récupérer le projet:

```sh
$ git clone https://github.com/essembeh/script-utils

```

Si vous n'avez pas *jq* dans le PATH, alors pluzzdl vous invite à le télécharger
```sh
$ pluzzdl.sh update
Cannot find jq in PATH, download binary from http://stedolan.github.io/jq/
Try running: 
 mkdir -p /home/seb/.pluzzdl/lib; wget -q http://stedolan.github.io/jq/download/linux64/jq -O "/home/seb/.pluzzdl/lib/jq" && chmod +x "/home/seb/.pluzzdl/lib/jq"
 
$  mkdir -p /home/seb/.pluzzdl/lib; wget -q http://stedolan.github.io/jq/download/linux64/jq -O "/home/seb/.pluzzdl/lib/jq" && chmod +x "/home/seb/.pluzzdl/lib/jq"

```

## Utilisation


### update

Pour mettre à jour la liste des vidéos disponibles, il faut ajouter l'argument *update"

```sh
$ pluzzdl.sh update
Archive:  update.zip
  inflating: catch_up_france2.json   
  inflating: catch_up_france3.json   
  inflating: catch_up_france4.json   
  inflating: catch_up_france5.json   
  inflating: catch_up_franceo.json   
  inflating: catch_up_france3_regions.json  
  inflating: catch_up_france1.json   
  inflating: guide_tv_2014-11-13_france2.json  
  inflating: guide_tv_2014-11-13_france3.json  
  inflating: guide_tv_2014-11-13_france4.json  
  inflating: guide_tv_2014-11-13_france5.json  
  inflating: guide_tv_2014-11-13_franceo.json  
  inflating: guide_tv_2014-11-13_reunion.json  
  inflating: guide_tv_2014-11-13_guyane.json  
  inflating: guide_tv_2014-11-13_polynesie.json  
  inflating: guide_tv_2014-11-13_martinique.json  
  inflating: guide_tv_2014-11-13_mayotte.json  
  inflating: guide_tv_2014-11-13_nouvellecaledonie.json  
  inflating: guide_tv_2014-11-13_guadeloupe.json  
  inflating: guide_tv_2014-11-13_wallisetfutuna.json  
  inflating: guide_tv_2014-11-13_saintpierreetmiquelon.json  
  inflating: categories.json         
  inflating: message_FT.json  
  
```

### search

Pour faire une recherche:
```sh
$ pluzzdl.sh search Artzooka   
[]
[]
[]
[]
[]
[
  {
    "id": "112138117",
    "titre1": "Artzooka !",
    "titre2": "",
    "url": "/hls-ios-inf/i/streaming-adaptatif_france-dom-tom/2014/S45/J6/112138117-20141108-,398,632,934,k.mp4.csmil/master.m3u8"
  }
]
[]

```

### download 

Pour télécharger les épisodes listés par la commande précédente:
```sh
$ pluzzdl.sh download Artzooka
Downloading video: [112138117] Artzooka/
  --> File created: /home/seb/.pluzzdl/done/Artzooka/112138117.mpg
  
```

Par défaut les vidéos sont téléchargées dans *~/.pluzzdl/done/*, pour changer ce comportement vous pouvez soit faire un lien symbolique soit éditer le script et changer la variable
*OUTPUT_DIR*.

Ce script garde une trace des éléments téléchargés afin de ne pas les retélécharger par la suite.
