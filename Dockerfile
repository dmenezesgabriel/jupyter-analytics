###########
# BUILDER #
###########

# Pull official base image
FROM python:3.8.2-slim-buster as builder
# Set work directory
ENV APP_HOME /usr/src/app
WORKDIR ${APP_HOME}
# Set envrionment variables
# Prevents Python from writing pyc files to disc (equivalent to python -B option)
ENV PYTHONDONTWRITEBYTECODE 1
# Prevents Python from buffering stdout and stderr (equivalent to python -u option)
ENV PYTHONBUFFERED 1
# Define python Language
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
# install python dependencies
RUN pip install --upgrade pip
COPY ./requirements.txt /usr/src/app/requirements.txt
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r requirements.txt
RUN pip install jupyterlab

#########
# FINAL #
#########

# pull official base image
FROM python:3.8.2-slim-buster
# create directory for the app user
RUN mkdir -p /home/app
# create the app user
RUN addgroup --system app && adduser --system --group app
# create the appropriate directories
ENV HOME=/home/app
ENV APP_HOME=/home/app/lab
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

# Install system dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
    curl
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash
RUN apt-get install -y nodejs
# confirm that it was successful
RUN node -v
# npm installs automatically
RUN npm -v
# install python
COPY --from=builder /usr/src/app/wheels /wheels
COPY --from=builder /usr/src/app/requirements.txt .
RUN pip install --upgrade pip
RUN pip install --no-cache /wheels/*
# Copy Configs
COPY ./conf/ /usr/local/etc/jupyter
COPY ./settings/ /usr/local/share/jupyter/lab/settings
# Install extensions
RUN jupyter labextension install @karosc/jupyterlab_dracula --no-build && \
    jupyter labextension install @krassowski/jupyterlab-lsp --no-build && \
    jupyter labextension install @ijmbarr/jupyterlab_spellchecker --no-build && \
    jupyter labextension install @jupyterlab/toc --no-build && \
    jupyter labextension install @aquirdturtle/collapsible_headings --no-build && \
    jupyter labextension install @krassowski/jupyterlab_go_to_definition --no-build && \
    jupyter lab clean && \
    jupyter lab build
# Copy entrypoint
COPY scripts/entrypoint.sh $APP_HOME
# Copy notebooks folder
COPY ./nbs/ $APP_HOME
# chown all the files to the app user
RUN chown -R app:app $HOME
# change to the app user
USER app
# run entrypoint.prod.sh
ENTRYPOINT ["/home/app/lab/entrypoint.sh"]