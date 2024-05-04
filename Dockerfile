FROM debian:bookworm

RUN sed -i -e's/ main/ main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources
RUN apt update -y && apt upgrade -y
RUN apt install -y dkms debhelper curl python3 python3-yaml apt-transport-https

RUN curl https://raw.githubusercontent.com/lernstick/lernstickAdvanced/debian12/config/archives/lernstick-12.list -o /etc/apt/sources.list.d/lernstick-12.list
RUN curl https://raw.githubusercontent.com/lernstick/lernstickAdvanced/debian12/config/archives/lernstick-12.key -o /etc/apt/trusted.gpg.d/lernstick-12.asc

RUN apt update -y && apt upgrade -y

# Uninstall linux headers beacuse otherwise dkms will always also build for this version.
RUN apt remove -y linux-headers-amd64 
RUN apt autoremove -y

COPY "create_dkms_debs.py" .

ENTRYPOINT ["/create_dkms_debs.py"]
CMD ["config.yaml"]
