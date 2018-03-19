 #!/bin/sh
set -u 
set -e 

docker run --rm -t -i \
	--volume $HOME:/target/home \
	--volume /tmp:/target/tmp \
	--volume $PWD:/target/pwd \
	--volume /tmp/.X11-unix/X0:/tmp/.X11-unix/X0 \
	--env DISPLAY=:0 \
	--workdir /target/pwd \
	"$@"

