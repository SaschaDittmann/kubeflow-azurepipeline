FROM tensorflow/tensorflow:2.1.2-gpu

RUN pip install --upgrade pip
RUN pip install --upgrade pillow
RUN pip install --upgrade prompt-toolkit==1.0.15 azureml-sdk==1.18.0
RUN pip install --upgrade azure-cli
RUN az extension add -n azure-cli-ml
RUN apt-get install jq -y

COPY score.py /scripts/score.py
COPY conda_dependencies.yml /scripts/env/conda_dependencies.yml
COPY azureml_environment.json /scripts/env/azureml_environment.json

COPY profile.sh /scripts/profile.sh
RUN chmod +x /scripts/profile.sh

# will be overwritten by kf pipeline
ENTRYPOINT [ "/scripts/profile.sh" ]
