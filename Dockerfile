FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive

COPY apt.postgresql.org.sh ./
COPY requirements.txt ./
COPY setup.sh ./

RUN apt-get update && apt-get install ca-certificates -y
RUN chmod +x setup.sh apt.postgresql.org.sh && ./setup.sh
RUN apt-get install software-properties-common -y
RUN add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get install python3.11 -y \
    && apt-get install python3-pip -y \
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN pip install -r requirements.txt

# Copy the app folder into the image
COPY --chmod=755 . .

EXPOSE 3000
