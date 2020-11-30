FROM mcr.microsoft.com/azure-cli
RUN az extension add -n azure-cli-ml
RUN pip install --upgrade pip

COPY score.py /scripts/score.py
COPY conda_dependencies.yml /scripts/env/conda_dependencies.yml
COPY azureml_environment.json /scripts/env/azureml_environment.json

COPY acideploymentconfig.json /scripts/acideploymentconfig.json
COPY aksdeploymentconfig.json /scripts/aksdeploymentconfig.json

COPY deploy.sh /scripts/deploy.sh
RUN chmod +x /scripts/deploy.sh

# will be overwritten by kf pipeline
ENTRYPOINT [ "/scripts/deploy.sh" ]
