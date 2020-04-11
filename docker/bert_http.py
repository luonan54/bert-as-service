import requests
import os
import random
import annoy
import numpy as np
import nltk
import json
import re

# get our sentence tokenizer
nltk.download('punkt')
from nltk.tokenize import sent_tokenize

# load our Bert endpoint
print("Detecting bert endpoint")

#uncomment to use your own, or enjoy mine.
#
#cmd = "gcloud compute addresses list | grep bert-ip | awk '{print $2}'"
#BERT_HTTP = 'http://'+os.popen(cmd).read().split()[0]+'/encode'
#
BERT_HTTP = 'http://bert.scott.ai/encode'
BERT_TENSOR_SIZE = 768

# other options are dot, hamming, angular.  dot seems best anecdotally.
BERT_TENSOR_DISTANCE = "dot"
BERT_TENSOR_DB = "bert.db"

# create our Annoy index
a = annoy.AnnoyIndex(BERT_TENSOR_SIZE, BERT_TENSOR_DISTANCE)

# sample data
print("loading sample data")
data = []
db = []
vecdb = []
with open('sample.json') as f:
  for one_liner in f:
    data.append(json.loads(one_liner))

# Simple BERT utilities
def bertify_array(text_array):
    "Turn an array of text, text_array, into an array of tensors. Sentences are best."
    # eid is our encoding id, which we really don't use as
    # bert is synchronous over http.
    eid = random.randint(1,1e6)
    r = requests.post(BERT_HTTP, json={"id": eid, "texts": text_array, "is_tokenized": False})
    v = r.json()
    try:
        if (v['status'] == 200):
            return np.array(v['result'])
        return None
    except:
        return None

def bertify(text):
    "Turn text into a tensor, sentences are best."
    ans = bertify_array([text])
    if ans is not None:
        ans = ans[0]
    return ans

def remove_html_tags(text):
    """Remove html tags from a string"""
    clean = re.compile('<.*?>')
    return re.sub(clean, '', text)

def clean_text(text):
  text = text.replace("\n\n"," EOP ")
  text = text.replace(".",". ")
  text = text.replace("\t"," ")
  text = text.replace("\n"," ")
  text = remove_html_tags(text)
  return text

def sentences(text):
  text = clean_text(text)
  return sent_tokenize(text)

def first_clean_sentences(text, k=10):
  sent = sentences(text)
  valid = []
  # k clean sentences
  while len(sent) > 0 and k > 0:
    s = sent.pop(0)
    if s.find('EOP') < 0  and len(s) > 10:
      valid.append(s)
      k = k-1
  return valid

def process_entry(entry):
  # very crude for now, we want to store this in feast
  info = {'url': entry['url_orig'],
          'title': entry['page_title'],
          'image_url': entry['keyimage'],
          'author': entry['meta_authors'],
          'domain': entry['domain_root'],
          'date': entry['date_fetch'],
          'vindex': len(vecdb)}
  n = len(db)
  db.append(info)
  sents = first_clean_sentences(entry['page_ftxt'])
  sents.insert(0,info['title'])
  info['text'] = sents
  vecs = bertify_array(sents)
  for i in range(0,len(vecs)):
    a.add_item(len(vecdb), vecs[i])
    vecdb.append([n, sents[i]])
  return sents

def process_data(d):
  for entry in d:
    print(process_entry(entry)[0])

def nearest_article(index):
  if index<0 or index>len(db):
    return None
  vindex = db[index]['vindex']
  vindices = a.get_nns_by_item(vindex,5)
  print("Closest to '"+db[index]['title']+"'")
  for v in vindices:
    showv(v)
    print("-----")

def showv(v):
  dindex = vecdb[v][0]
  sentence  = vecdb[v][1]
  entry = db[dindex]
  print("  "+entry['domain']+": "+entry['title'])
  print("  \""+sentence+"\"")

def nearest(question):
  vec = bertify(question)
  near  = a.get_nns_by_vector(vec,5)
  for n in near:
    showv(n)
    print("-----")

def do100():
  for i in range(0,100):
    print(data[i]['page_title'])
    for s in process_entry(data[i]):
      print("  > ",s)

def save_bert():
  a.build(10) # once called, we can't add more data
  a.save(BERT_TENSOR_DB)
