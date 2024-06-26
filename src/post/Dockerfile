FROM python:3.6.0-alpine
# FROM python:3.11-slim-buster

WORKDIR /app
COPY . /app

RUN apk --no-cache --update add build-base gcc musl-dev && \
    pip install --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org --upgrade pip && \
    pip install -r /app/requirements.txt && \
    apk del build-base

ENV POST_DATABASE_HOST post_db
ENV POST_DATABASE posts

ENTRYPOINT ["python3", "post_app.py"]
