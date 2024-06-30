FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive

COPY apt.postgresql.org.sh ./
COPY requirements.txt ./
COPY setup.sh ./

RUN apt-get update && apt-get install ca-certificates -y
RUN chmod +x setup.sh apt.postgresql.org.sh && ./setup.sh
RUN apt-get install software-properties-common -y \
RUN add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get install python3.11 -y \
    && apt-get install python3-pip -y \
RUN pip install -r --break-system-packages --root-user-action=ignore requirements.txt


# Copy the app folder into the image
COPY --chmod=755 . .

EXPOSE 3000
