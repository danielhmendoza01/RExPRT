import pandas as pd
import statistics
import os
import numpy as np
from sklearn import model_selection
from sklearn.metrics import classification_report, confusion_matrix
from sklearn import svm
from xgboost import XGBClassifier
from sklearn.preprocessing import MinMaxScaler
from sklearn.pipeline import make_pipeline
from sklearn import preprocessing
import category_encoders as ce
from sklearn import datasets, metrics, model_selection, svm
import pickle

#Load SVM model
infile = open('data/SVM.pckl', 'rb')
model_SVM = pickle.load(infile)
infile.close()

#Load XGB model
infile = open('data/XGB.pckl', 'rb')
model_XGB = pickle.load(infile)
infile.close()

#Load TRs
print("Loading TR data...")
TRs = pd.read_csv("final_annotated.txt", sep="\t", header=0)
print(f"Loaded {len(TRs)} tandem repeats")

# Set batch size for memory efficiency (adjust based on available RAM)
BATCH_SIZE = 10000  # Process in batches of 10k to prevent memory issues

print(f"Processing in batches of {BATCH_SIZE}...")

# Prepare feature arrays
X_SVM_unseen = np.array(TRs[['eSTR', 'TAD','location_Middle','location_First','location_Last','region_exon','UTR_3','UTR_5','promoter','tissue_simple_Nervous_System','tissue_simple_No_expression','tissue_simple_Other','gerp','loeuf','pLi','gc_content','gene_distance','per_c','per_t','per_a','per_g']])
X_XGB_unseen = np.array(TRs[['RAD21','opReg','location_Middle','location_First','location_Last','region_intron','region_exon','UTR_5','promoter','tissue_simple_Nervous_System','tissue_simple_Other','tissue_simple_No_expression','gerp','eSh0','eTr2','eTr3','eS6','eS','eX1R','eX2','eX5']])

# Initialize result arrays
yhat_SVM = np.zeros((len(TRs), 2))
yhat_XGB = np.zeros((len(TRs), 2))

# Process in batches for memory efficiency
num_batches = (len(TRs) + BATCH_SIZE - 1) // BATCH_SIZE
print(f"Processing {num_batches} batches...")

for i in range(num_batches):
    start_idx = i * BATCH_SIZE
    end_idx = min((i + 1) * BATCH_SIZE, len(TRs))

    print(f"Batch {i+1}/{num_batches}: Processing rows {start_idx} to {end_idx-1}...")

    # Get batch data
    X_SVM_batch = X_SVM_unseen[start_idx:end_idx]
    X_XGB_batch = X_XGB_unseen[start_idx:end_idx]

    # Make predictions for this batch
    yhat_SVM[start_idx:end_idx] = model_SVM.predict_proba(X_SVM_batch)
    yhat_XGB[start_idx:end_idx] = model_XGB.predict_proba(X_XGB_batch)

print("All predictions completed!")

TRs['SVM'] = yhat_SVM[:,1]
TRs['XGB'] = yhat_XGB[:,1]

# add the ensemble confidence score
TRs['ensembleScore'] = (TRs['SVM'] + TRs['XGB'])

# take the maximum out of the two for binary
TRs["ensembleMax"] = TRs[["SVM", "XGB"]].max(axis=1)
TRs['ensembleBinary'] = np.where(TRs['ensembleMax'] >= 0.5, 1, 0)

# save DF with scores and annotations
TRs.to_csv("TRsAnnotated_RExPRTscoresDups.txt", sep="\t", index=False)

# save df with only the scores
only_scores = TRs[['chr', 'start', 'end', 'motif','sampleID', 'gene', 'SVM','XGB','ensembleScore','ensembleBinary','ensembleMax']]
only_scores.to_csv("RExPRT_scoresDups.txt", sep="\t", index=False)
