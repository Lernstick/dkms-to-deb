FROM debian:trixie

RUN sed -i -e's/ main/ main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources
RUN apt update -y && apt upgrade -y && apt install -y curl apt-transport-https
RUN curl https://raw.githubusercontent.com/lernstick/lernstickAdvanced/debian13/config/archives/lernstick-13.list -o /etc/apt/sources.list.d/lernstick-12.list
RUN curl https://raw.githubusercontent.com/lernstick/lernstickAdvanced/debian13/config/archives/lernstick-13.key -o /etc/apt/trusted.gpg.d/lernstick-12.asc

RUN apt update -y && apt upgrade -y

# Uninstall linux headers beacuse otherwise dkms will always also build for this version.
RUN apt remove -y linux* && apt autoremove -y && apt-get install --no-install-recommends -y binutils-gold build-essential debhelper dkms python3 python3-yaml 

COPY "create_dkms_debs.py" .

ENTRYPOINT ["/create_dkms_debs.py"]
CMD ["config.yaml"]
