FROM mcr.microsoft.com/azure-cli:latest

ENV KUBE_LATEST_VERSION="v1.12.2"
ENV HELM_LATEST_VERSION="v3.5.3"
ENV TERRAFORM_VERSION="0.14.9"

RUN apk add --update ca-certificates \
 && apk add --update -t deps curl \
 && curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
 && chmod +x /usr/local/bin/kubectl \
 && wget https://get.helm.sh/helm-${HELM_LATEST_VERSION}-linux-amd64.tar.gz \
 && tar -xvf helm-${HELM_LATEST_VERSION}-linux-amd64.tar.gz \
 && mv linux-amd64/helm /usr/local/bin \
 && rm -f /helm-${HELM_LATEST_VERSION}-linux-amd64.tar.gz \
 && apk del --purge deps \
 && rm /var/cache/apk/*

RUN cd /usr/local/bin && \
    curl https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

RUN  curl -o- -L https://toolkit.fluxcd.io/install.sh | bash