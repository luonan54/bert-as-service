FROM gcr.io/deeplearning-platform-release/tf-gpu.1-14
RUN pip install --upgrade pip
RUN pip install -U bert-serving-server[http]
COPY ./ /app
COPY ./docker/entrypoint.sh /app
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
