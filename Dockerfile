ARG DEBIAN=buster

FROM debian:${DEBIAN}-slim
LABEL maintainer="Mathias Fredriksson <mafredri@gmail.com>"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
	live-build \
	rsync \
	&& rm -rf /var/lib/apt/lists/*

# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=919659
RUN sed -i '1161s%umount%#umount%' /usr/share/debootstrap/functions

VOLUME ["/work"]
COPY . /work
WORKDIR /work
CMD ["bash", "--login"]
