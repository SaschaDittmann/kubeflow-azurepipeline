import kfp.dsl as dsl
from kubernetes import client as k8s_client

@dsl.pipeline(
    name='Tacos vs. Burritos',
    description='Simple TF CNN for binary classifier between burritos and tacos'
)
def tacosandburritos_train(
    tenant_id,
    service_principal_id,
    service_principal_password,
    subscription_id,
    resource_group,
    workspace,
    persistent_volume_name='azure',
    persistent_volume_path='/mnt/azure',
    data_download='https://github.com/SaschaDittmann/kubeflow-azurepipeline/raw/main/data/tacodata.zip',
    epochs=5,
    batch=32,
    learning_rate=0.0001,
    imagetag='latest',
    model_name='tacosandburritos',
    profile_name='tacoprofile',
    service_name='tacosandburritos-service'
):

    operations = {}
    image_size = 160
    training_folder = 'train'
    training_dataset = 'train.txt'
    model_folder = 'model'

    # preprocess data
    operations['preprocess'] = dsl.ContainerOp(
        name='preprocess',
        image='bytesmith/kubeflow-azurepipeline:latest-preprocess',
        command=['python'],
        arguments=[
            '/scripts/data.py',
            '--base_path', persistent_volume_path,
            '--data', training_folder,
            '--target', training_dataset,
            '--img_size', image_size,
            '--zipfile', data_download
        ]
    )

    #train
    operations['training'] = dsl.ContainerOp(
        name='training',
        image='bytesmith/kubeflow-azurepipeline:latest-training',
        command=['python'],
        arguments=[
            '/scripts/train.py',
            '--base_path', persistent_volume_path,
            '--data', training_folder, 
            '--epochs', epochs, 
            '--batch', batch, 
            '--image_size', image_size, 
            '--lr', learning_rate, 
            '--outputs', model_folder, 
            '--dataset', training_dataset
        ]
    )
    operations['training'].after(operations['preprocess'])

    # register model
    operations['register'] = dsl.ContainerOp(
        name='register',
        image='bytesmith/kubeflow-azurepipeline:latest-register',
        command=['python'],
        arguments=[
            '/scripts/register.py',
            '--base_path', persistent_volume_path,
            '--model', 'latest.h5',
            '--model_name', model_name,
            '--tenant_id', tenant_id,
            '--service_principal_id', service_principal_id,
            '--service_principal_password', service_principal_password,
            '--subscription_id', subscription_id,
            '--resource_group', resource_group,
            '--workspace', workspace
        ]
    )
    operations['register'].after(operations['training'])

    operations['profile'] = dsl.ContainerOp(
        name='profile',
        image='bytesmith/kubeflow-azurepipeline:latest-profile',
        command=['/bin/bash'],
        arguments=[
            '/scripts/profile.sh',
            '-n', profile_name,
            '-e', '/scripts/score.py',
            '-d', '{ "schemaVersion": 1, "datasetType": "Tabular", "parameters": { "path": [ "https://github.com/SaschaDittmann/kubeflow-azurepipeline/raw/master/data/profiledata.json" ], "sourceType": "json_lines_files" }, "registration": { "createNewVersion": true, "name": "tacosandburritos-dataset", "tags": { "mlops-system": "kubeflow" } } }',
            '-t', tenant_id,
            '-r', resource_group,
            '-w', workspace,
            '-s', service_principal_id,
            '-p', service_principal_password,
            '-u', subscription_id,
            '-b', persistent_volume_path
        ]
    )
    operations['profile'].after(operations['register'])

    operations['deploy'] = dsl.ContainerOp(
        name='deploy',
        image='bytesmith/kubeflow-azurepipeline:latest-deploy',
        command=['/bin/bash'],
        arguments=[
            '/scripts/deploy.sh',
            '-n', service_name,
            '-e', '/scripts/score.py',
            '-d', '/scripts/acideploymentconfig.json',
            '-t', tenant_id,
            '-r', resource_group,
            '-w', workspace,
            '-s', service_principal_id,
            '-p', service_principal_password,
            '-u', subscription_id,
            '-b', persistent_volume_path
        ]
    )
    operations['deploy'].after(operations['profile'])

    for _, op in operations.items():
        op.container.set_image_pull_policy("Always")
        op.add_volume(
            k8s_client.V1Volume(
                name='azure',
                persistent_volume_claim=k8s_client.V1PersistentVolumeClaimVolumeSource(
                    claim_name='azure-managed-disk')
                )
            ).add_volume_mount(k8s_client.V1VolumeMount(
                mount_path='/mnt/azure', 
                name='azure')
            )


if __name__ == '__main__':
   import kfp.compiler as compiler
   compiler.Compiler().compile(tacosandburritos_train, __file__ + '.tar.gz')
