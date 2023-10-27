#!/usr/bin/python
# coding=utf-8
#
# @title: Data Preparation Script for CSS Reference Dataset
"""
Two pre-processing steps:

1. Restructure as binary task.
2. Add embedding distance to reference document.

"""

from typing import List, Dict
from pathlib import Path
import numpy as np
import pandas as pd
from tqdm import tqdm
import torch
from sentence_transformers import SentenceTransformer
from scipy.spatial.distance import cosine
from css_mappings import binary_positive_class, embed_text_map

out_dir = Path.cwd()/'binarized_datasets'
out_dir.mkdir(exist_ok=True, parents=True) if not out_dir.exists() else None

# %% Read in data
data_dir = Path.cwd()/'reconstructed_datasets'
data_files = sorted(data_dir.glob('*.json'))
task_df = pd.read_csv('task_overview.csv')
dfs = {f.stem: pd.read_json(f) for f in data_files}
binary_tasks = list(binary_positive_class.keys())

# Init sentence transformer model
torch.manual_seed(1234)
model = SentenceTransformer('all-mpnet-base-v2')
assert torch.cuda.is_available()
model.eval()


def calculate_cosine_distance(
    model: SentenceTransformer | str,
    target_text: str,
    texts: List[str],
    batch_size: int = 128,
    random_seed: int = 1234,
) -> np.ndarray:
    "Add embedding cosine distance"
    torch.manual_seed(random_seed)
    # Init model
    if isinstance(model, str):
        model = SentenceTransformer(model)
    target_embed = model.encode(target_text, show_progress_bar=False)
    with torch.no_grad():
        embeds = model.encode(texts, batch_size=batch_size,
                              show_progress_bar=False)
    distances = np.apply_along_axis(
        func1d=lambda embed: cosine(target_embed, embed), axis=1, arr=embeds
    )
    return distances


def prep_binary(dfs: Dict[str, pd.DataFrame], task_name: str) -> pd.DataFrame:
    # Get source df
    df = dfs[task_name].copy()
    # Get relevant columns
    q_cols = df.columns[df.columns.str.startswith('q')].tolist()
    # Get positive class
    pos_class = binary_positive_class[task_name]
    assert pos_class in df['gold'].unique(
    ), f'{pos_class} is not among class labels.'
    # Map columns
    df.loc[:, 'label'] = df['gold'].apply(lambda s: 1 if s == pos_class else 0)
    # Map remaining columns
    df.loc[:, q_cols] = df.loc[:, q_cols].applymap(
        lambda s: 1 if s == pos_class else 0)
    # Generate embeddings
    target_text = embed_text_map[task_name][pos_class]
    df.loc[:, 'dist_embeds'] = calculate_cosine_distance(
        model, target_text, df["context"].tolist(), batch_size=128,
    )
    # Return label, text and q_cols
    return df.loc[:, ['label', 'dist_embeds'] + q_cols]


def prep_multiclass(dfs: Dict[str, pd.DataFrame], task_name: str) -> Dict[str, pd.DataFrame]:
    df = dfs[task_name].copy()
    # Get relevant columns
    q_cols = df.columns[df.columns.str.startswith('q')].tolist()
    # Get classes
    classes = df['gold'].unique()
    # Iterate over classes
    out = {}
    for pos_class in tqdm(classes):
        # Remap labels to binary
        out_df = df.loc[:, ['gold']+q_cols].copy()
        out_df = out_df.applymap(
            lambda s: 1 if s == pos_class else 0)
        # Add embeddings
        target_text = embed_text_map[task_name][pos_class]
        out_df.loc[:, 'dist_embeds'] = calculate_cosine_distance(
            model, target_text, df["context"].tolist(), batch_size=128,
        )
        out_df.rename({'gold': 'label'}, axis=1, inplace=True)
        out[pos_class] = out_df.loc[:, ['label', 'dist_embeds'] + q_cols]
    return out


def main():
    for task_name in tqdm(task_df['name']):
        try:
            if task_name in binary_positive_class.keys():
                df = prep_binary(dfs, task_name)
                df.to_csv(
                    out_dir/f'binary_{task_name}_pos-{binary_positive_class[task_name]}.csv')
            else:
                mdf = prep_multiclass(dfs, task_name)
                for pos_class, df in mdf.items():
                    df.to_csv(out_dir/f'multi_{task_name}_pos-{pos_class}.csv')
        except Exception as e:
            print(task_name, e)
            continue


if __name__ == "__main__":
    main()
