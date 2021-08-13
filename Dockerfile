FROM debian:bullseye

RUN sed -i -e's/ main/ main contrib non-free/g' /etc/apt/sources.list
RUN apt update -y && apt upgrade -y
RUN apt install -y dkms debhelper curl python3 python3-yaml

RUN curl https://raw.githubusercontent.com/imedias/lernstickAdvanced/debian11/config/archives/lernstick-11.list -o /etc/apt/sources.list.d/lernstick-11.list
RUN curl https://raw.githubusercontent.com/imedias/lernstickAdvanced/debian11/config/archives/lernstick-11.key | apt-key add -

RUN apt update -y && apt upgrade -y

# Uninstall linux headers beacuse otherwise dkms will always also build for this version.
RUN apt remove -y linux-headers-amd64 
RUN apt autoremove -y

COPY "create_dkms_debs.py" .

ENTRYPOINT ["/create_dkms_debs.py"]
CMD ["config.yaml"]
