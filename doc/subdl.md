# subdl

### NAME

    subdl - Subtitle downloader version 1.1

### USAGE

    subdl --verbose --(no)force --(no)autopack --(no)autosrt --(no)clean 
          --(no)utf8 --site=(steu|tvnet) --lang=(fr|en) <EPISODE> ...
           
### OPTIONS

    --help
        Diplay this message.

    -f, --force
    --noforce   (default)
        To force srt download even if srt file is already present.
        By default if a srt file is present, nohting will be done.

    -v, --verbose 
        To display debug informations.

    --autopack   (default)
    --noautopack 
        Automatically try to fetch the pack of subtitles corresponding to the 
        given episode from its number.
        If no result, try --allzip to show all available srt zip files.
    
    --autosrt   (default)
    --noautosrt
        Automatically try to choose the srt that better matches the episode 
        name using the Levenshtein distance.

    -c, --clean   (default) 
    --noclean 
        Cleans (or not) tags if the srt files has some.

    -u, --utf8   (default)
    --noutf8 
        Converts the srt file encoding to utf8.
    
    --site=(steu|tvnet)   
        default=steu
        Set the site to use to get subtitles. Available sites are 
         * www.sous-titres.eu (steu)
         * www.tvsubtitles.net (tvnet)
    
    --lang=(fr|en)   
        default=fr
        The lang of the subtitles to fetch.

### EXAMPLES

    subdl --force --verbose --clean My.Serie.S02E04.mkv
        Automatically try to download subtitles for the episode 2x04.
        Then choose the better one. 
        Finally, the srt file will get its tags removed.
        Note: if a My.Serie.S02E04.srt already exists, it will be overwritten.

### COPYRIGHT

    Copyright 2011 essembeh.org
    Licence GPLv2.
