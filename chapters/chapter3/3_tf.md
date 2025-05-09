# Fine-tuning a model with Keras


Once you've done all the data preprocessing work in the last section, you have just a few steps left to train the model. Note, however, that the `model.fit()` command will run very slowly on a CPU. If you don't have a GPU set up, you can get access to free GPUs or TPUs on [Google Colab](https://colab.research.google.com/).

The code examples below assume you have already executed the examples in the previous section. Here is a short summary recapping what you need:

```py
from datasets import load_dataset
from transformers import AutoTokenizer, DataCollatorWithPadding
import numpy as np

raw_datasets = load_dataset("glue", "mrpc")
checkpoint = "bert-base-uncased"
tokenizer = AutoTokenizer.from_pretrained(checkpoint)


def tokenize_function(example):
    return tokenizer(example["sentence1"], example["sentence2"], truncation=True)


tokenized_datasets = raw_datasets.map(tokenize_function, batched=True)

data_collator = DataCollatorWithPadding(tokenizer=tokenizer, return_tensors="tf")

tf_train_dataset = tokenized_datasets["train"].to_tf_dataset(
    columns=["attention_mask", "input_ids", "token_type_ids"],
    label_cols=["labels"],
    shuffle=True,
    collate_fn=data_collator,
    batch_size=8,
)

tf_validation_dataset = tokenized_datasets["validation"].to_tf_dataset(
    columns=["attention_mask", "input_ids", "token_type_ids"],
    label_cols=["labels"],
    shuffle=False,
    collate_fn=data_collator,
    batch_size=8,
)
```

### Training

TensorFlow models imported from 🤗 Transformers are already Keras models. Here is a short introduction to Keras.

<h3>Watch the Youtube video</h3>
<a href="https://www.youtube.com/watch?v=00GKzGyWFEs" target="_blank">
    <img src="https://img.youtube.com/vi/00GKzGyWFEs/0.jpg" alt="Watch on YouTube" style="width:100%;max-width:600px;">
</a>

That means that once we have our data, very little work is required to begin training on it.

<h3>Watch the Youtube video</h3>
<a href="https://www.youtube.com/watch?v=00GKzGyWFEs" target="_blank">
    <img src="https://img.youtube.com/vi/00GKzGyWFEs/0.jpg" alt="Watch on YouTube" style="width:100%;max-width:600px;">
</a>

As in the previous chapter, we will use the `TFAutoModelForSequenceClassification` class, with two labels: 

```py
from transformers import TFAutoModelForSequenceClassification

model = TFAutoModelForSequenceClassification.from_pretrained(checkpoint, num_labels=2)
```

You will notice that unlike in Chapter 2, you get a warning after instantiating this pretrained model. This is because BERT has not been pretrained on classifying pairs of sentences, so the head of the pretrained model has been discarded and a new head suitable for sequence classification has been inserted instead. The warnings indicate that some weights were not used (the ones corresponding to the dropped pretraining head) and that some others were randomly initialized (the ones for the new head). It concludes by encouraging you to train the model, which is exactly what we are going to do now.

To fine-tune the model on our dataset, we just have to `compile()` our model and then pass our data to the `fit()` method. This will start the fine-tuning process (which should take a couple of minutes on a GPU) and report training loss as it goes, plus the validation loss at the end of each epoch.

<div style="background-color: #FFF4E5; border-left: 4px solid #F97316; padding: 10px; color: black; max-width: 600px;">

Note that 🤗 Transformers models have a special ability that most Keras models don't - they can automatically use an appropriate loss which they compute internally. They will use this loss by default if you don't set a loss argument in `compile()`. Note that to use the internal loss you'll need to pass your labels as part of the input, not as a separate label, which is the normal way to use labels with Keras models. You'll see examples of this in Part 2 of the course, where defining the correct loss function can be tricky. For sequence classification, however, a standard Keras loss function works fine, so that's what we'll use here.

</div>

```py
from tensorflow.keras.losses import SparseCategoricalCrossentropy

model.compile(
    optimizer="adam",
    loss=SparseCategoricalCrossentropy(from_logits=True),
    metrics=["accuracy"],
)
model.fit(
    tf_train_dataset,
    validation_data=tf_validation_dataset,
)
```

<Tip warning={true}>

Note a very common pitfall here — you *can* just pass the name of the loss as a string to Keras, but by default Keras will assume that you have already applied a softmax to your outputs. Many models, however, output the values right before the softmax is applied, which are also known as the *logits*. We need to tell the loss function that that's what our model does, and the only way to do that is to call it directly, rather than by name with a string.

</div>


### Improving training performance

<h3>Watch the Youtube video</h3>
<a href="https://www.youtube.com/watch?v=00GKzGyWFEs" target="_blank">
    <img src="https://img.youtube.com/vi/00GKzGyWFEs/0.jpg" alt="Watch on YouTube" style="width:100%;max-width:600px;">
</a>

If you try the above code, it certainly runs, but you'll find that the loss declines only slowly or sporadically. The primary cause
is the *learning rate*. As with the loss, when we pass Keras the name of an optimizer as a string, Keras initializes
that optimizer with default values for all parameters, including learning rate. From long experience, though, we know
that transformer models benefit from a much lower learning rate than the default for Adam, which is 1e-3, also written
as 10 to the power of -3, or 0.001. 5e-5 (0.00005), which is some twenty times lower, is a much better starting point.

In addition to lowering the learning rate, we have a second trick up our sleeve: We can slowly reduce the learning rate
over the course of training. In the literature, you will sometimes see this referred to as *decaying* or *annealing*
the learning rate. In Keras, the best way to do this is to use a *learning rate scheduler*. A good one to use is
`PolynomialDecay` — despite the name, with default settings it simply linearly decays the learning rate from the initial
value to the final value over the course of training, which is exactly what we want. In order to use a scheduler correctly,
though, we need to tell it how long training is going to be. We compute that as `num_train_steps` below.

```py
from tensorflow.keras.optimizers.schedules import PolynomialDecay

batch_size = 8
num_epochs = 3
# The number of training steps is the number of samples in the dataset, divided by the batch size then multiplied
# by the total number of epochs. Note that the tf_train_dataset here is a batched tf.data.Dataset,
# not the original Hugging Face Dataset, so its len() is already num_samples // batch_size.
num_train_steps = len(tf_train_dataset) * num_epochs
lr_scheduler = PolynomialDecay(
    initial_learning_rate=5e-5, end_learning_rate=0.0, decay_steps=num_train_steps
)
from tensorflow.keras.optimizers import Adam

opt = Adam(learning_rate=lr_scheduler)
```

<div style="background-color: #FFF4E5; border-left: 4px solid #F97316; padding: 10px; color: black; max-width: 600px;">

The 🤗 Transformers library also has a `create_optimizer()` function that will create an `AdamW` optimizer with learning rate decay. This is a convenient shortcut that you'll see in detail in future sections of the course.

</div>

Now we have our all-new optimizer, and we can try training with it. First, let's reload the model, to reset the changes to the weights from the training run we just did, and then we can compile it with the new optimizer:

```py
import tensorflow as tf

model = TFAutoModelForSequenceClassification.from_pretrained(checkpoint, num_labels=2)
loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
model.compile(optimizer=opt, loss=loss, metrics=["accuracy"])
```

Now, we fit again:

```py
model.fit(tf_train_dataset, validation_data=tf_validation_dataset, epochs=3)
```

<div style="background-color: #FFF4E5; border-left: 4px solid #F97316; padding: 10px; color: black; max-width: 600px;">

💡 If you want to automatically upload your model to the Hub during training, you can pass along a `PushToHubCallback` in the `model.fit()` method. We will learn more about this in Chapter 4

</div>

### Model predictions

<h3>Watch the Youtube video</h3>
<a href="https://www.youtube.com/watch?v=00GKzGyWFEs" target="_blank">
    <img src="https://img.youtube.com/vi/00GKzGyWFEs/0.jpg" alt="Watch on YouTube" style="width:100%;max-width:600px;">
</a>


Training and watching the loss go down is all very nice, but what if we want to actually get outputs from the trained model, either to compute some metrics, or to use the model in production? To do that, we can just use the `predict()` method. This will return the *logits* from the output head of the model, one per class.

```py
preds = model.predict(tf_validation_dataset)["logits"]
```

We can convert these logits into the model's class predictions by using `argmax` to find the highest logit, which corresponds to the most likely class:

```py
class_preds = np.argmax(preds, axis=1)
print(preds.shape, class_preds.shape)
```

```python out
(408, 2) (408,)
```

Now, let's use those `preds` to compute some metrics! We can load the metrics associated with the MRPC dataset as easily as we loaded the dataset, this time with the `evaluate.load()` function. The object returned has a `compute()` method we can use to do the metric calculation:

```py
import evaluate

metric = evaluate.load("glue", "mrpc")
metric.compute(predictions=class_preds, references=raw_datasets["validation"]["label"])
```

```python out
{'accuracy': 0.8578431372549019, 'f1': 0.8996539792387542}
```

The exact results you get may vary, as the random initialization of the model head might change the metrics it achieved. Here, we can see our model has an accuracy of 85.78% on the validation set and an F1 score of 89.97. Those are the two metrics used to evaluate results on the MRPC dataset for the GLUE benchmark. The table in the [BERT paper](https://arxiv.org/pdf/1810.04805.pdf) reported an F1 score of 88.9 for the base model. That was the `uncased` model while we are currently using the `cased` model, which explains the better result.

This concludes the introduction to fine-tuning using the Keras API. An example of doing this for most common NLP tasks will be given in Chapter 7. If you would like to hone your skills on the Keras API, try to fine-tune a model on the GLUE SST-2 dataset, using the data processing you did in section 2.

# Practice Time: Run the Code

[Google Colab](https://colab.research.google.com/github/huggingface/notebooks/blob/master/course/en/chapter3/section3_tf.ipynb)
[Aws Studio](https://studiolab.sagemaker.aws/import/github/huggingface/notebooks/blob/master/course/en/chapter3/section3_tf.ipynb)