import json
import time
import requests
import datetime
import numpy as np
from PIL import Image
from io import BytesIO
import tensorflow as tf

from azureml.core.model import Model

model = None

def init():
    global model

    try:
        model_path = Model.get_model_path('tacosandburritos')
    except:
        model_path = '/model/latest.h5'

    print('Attempting to load model from {}'.format(model_path))
    model = tf.keras.models.load_model(model_path)
    model.summary()
    print('Done!')

    print('Initialized model "{}" at {}'.format(model_path, datetime.datetime.now()))

def run(raw_data):
    global model
    prev_time = time.time()
    print('Input ({})'.format(raw_data))

    try:
        post = json.loads(raw_data)
        if type(post) is dict:
            img_path = post['image']
        elif type(post) is str:
            img_path = post
        else:
            print("Unable to parse raw_data.")
            return
    except ValueError:
        img_path = raw_data

    tensor = process_image(img_path, 160)
    t = tf.reshape(tensor, [-1, 160, 160, 3])
    o = model.predict(t, steps=1)#[0][0]
    print(o)
    o = o[0][0]

    current_time = time.time()

    inference_time = datetime.timedelta(seconds=current_time - prev_time)

    payload = {
        'time': inference_time.total_seconds(),
        'prediction': 'burrito' if o > 0.5 else 'tacos',
        'scores': str(o)
    }

    print('Input ({}), Prediction ({})'.format(img_path, payload))

    return payload

def process_image(path, image_size):
    # Extract image (from web or path)
    if(path.startswith('http')):
        response = requests.get(path)
        img = np.array(Image.open(BytesIO(response.content)))
    else:
        img = np.array(Image.open(path))

    img_tensor = tf.convert_to_tensor(img, dtype=tf.float32)
    img_final = tf.image.resize(img_tensor, [image_size, image_size]) / 255
    return img_final
    
def info(msg, char = "#", width = 75):
    print("")
    print(char * width)
    print(char + "   %0*s" % ((-1*width)+5, msg) + char)
    print(char * width)

if __name__ == "__main__":
    images = {
        'tacos': 'https://c1.staticflickr.com/5/4022/4401140214_f489c708f0_b.jpg',
        'burrito': 'https://www.exploreveg.org/files/2015/05/sofritas-burrito.jpeg'
    }

    init()

    for k, v in images.items():
        print('{} => {}'.format(k, v))

    info('Taco Test')
    print(images['tacos'])
    run(images['tacos'])

    info('Burrito Test')
    print(images['burrito'])
    run(images['burrito'])
