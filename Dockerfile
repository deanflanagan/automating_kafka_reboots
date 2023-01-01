FROM eclipse-temurin-11-jre-alpine
ARG POD_NAME="kafka-scripts-pod"
LABEL container=$POD_NAME \
      squad="data-engineering" \
      repository="data-engineering/kafka-scripts-pod"

# Prepare the work directory

ENV HOME /home/deploy 
ENV PYTHONPATH="/usr/lib/python3.10/site-packages"
RUN adduser -D deploy
WORKDIR $HOME

# ADD _only_ the few scripts needed for the deployed container...
COPY rebooter/ ${HOME}/rebooter/

RUN pip install  ${HOME}/rebooter

RUN chmod u+x $HOME/bin/*
RUN chown -R deploy:deploy ${HOME}

USER deploy

