#!/usr/bin/python
#
# @title: Additional Covariates
"""
Adding more covariates from the CBP version of the dataset and sentence embeddings for computing cosine distances.
"""

import re
import logging
from pathlib import Path
from dataclasses import dataclass
from typing import List, Callable, Dict
from datetime import datetime

import numpy as np
import pandas as pd
from tqdm import tqdm
from Levenshtein import ratio as Lv_ratio
from scipy.spatial.distance import cosine
import statsmodels.api as sm

import torch
from sentence_transformers import SentenceTransformer

assert torch.cuda.is_available()

# Logger init
logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(name)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)
logger = logging.getLogger()

# Directories
data_dir = Path.cwd() / "cbp_data"
output_dir = Path.cwd() / "cbp_data"


# Base dataframe, output of step 1
def prep_source_data(
    data_file: Path | str,
    covariates: List[str],
    data_ops: Dict[str, Dict[str, str | Callable]] = None,
) -> pd.DataFrame:
    # Get original dataset and add new columns
    df = pd.read_csv(data_file)
    # Perform data ops
    for name, op in data_ops.items():
        df.loc[:, name] = df[op["col"]].apply(op["op"])
    return df.loc[:, covariates + list(data_ops.keys())]


# dataclass for reading in results
@dataclass
class Result:
    nshot: str
    path: Path
    result_colname: str


# Functions for parsing outputs
def get_positive_probs(tokens: List[str], probs: List[float]):
    pos_idxs = [i for i in range(
        len(tokens)) if tokens[i].strip().lower() == "true"]
    neg_idxs = [i for i in range(
        len(tokens)) if tokens[i].strip().lower() == "false"]
    pos_mass = sum(probs[i] for i in pos_idxs)
    neg_mass = sum(probs[i] for i in neg_idxs)
    total_mass = pos_mass + neg_mass
    pred = True if pos_mass > neg_mass else False
    return pred, pos_mass / total_mass, total_mass


def add_llm_predictions(df: pd.DataFrame, results: List[Result]) -> pd.DataFrame:
    # Extract preds and probs
    for res in results:
        # Read data
        res_df = pd.read_csv(res.path)
        # Get text cols
        textcol = f"q_gpt3_{res.nshot}shot"
        probcol = f"ppos_gpt3_{res.nshot}shot"
        totalprobcol = f"ptotal_gpt3_{res.nshot}shot"
        # Extract data
        text_cols = [c for c in res_df.columns if re.match("res[0-9]_text", c)]
        pred_cols = [c for c in res_df.columns if re.match("res[0-9]_prob", c)]
        # Add prob cols, merge
        (
            res_df.loc[:, textcol],
            res_df.loc[:, probcol],
            res_df.loc[:, totalprobcol],
        ) = zip(
            *res_df.apply(
                lambda row: get_positive_probs(
                    row[text_cols].tolist(), row[pred_cols].tolist()
                ),
                axis=1,
            )
        )
        # Merge
        df = pd.merge(
            df,
            res_df.loc[:, ["bill_id", textcol, probcol, totalprobcol]],
            on="bill_id",
            how="left",
        )
    return df


# Functions for dealing with CBP data
def standardize_bill_id(s) -> str:
    parts = s.split("-")
    if len(parts) != 3:
        print(f"{s} is not a valid bill id.")
        return s
    parts[1] = "HR" if parts[1][0] == "H" else "S"
    s = "-".join(parts)
    return s


def add_extra_cbp_labels(df: pd.DataFrame) -> pd.DataFrame:
    """
    Some gnarly merging code.
    """
    cbp1 = pd.read_csv("http://congressionalbills.org/billfiles/bills80-92.zip",
                       sep='\t', encoding='latin-1', low_memory=False)
    cbp2 = pd.read_csv(
        "http://congressionalbills.org/billfiles/bills93-114.zip", sep=';', encoding='latin-1')
    # For testing
    # data_path = Path("~/Dropbox/xxxxx/datasets/cap").expanduser()
    # cbp1 = pd.read_csv(
    #     data_path / "bills80-92.txt", sep="\t", encoding="latin-1", low_memory=False
    # )
    # cbp2 = pd.read_csv(data_path / "bills93-114.csv", sep=";", encoding="latin-1")
    cbp = pd.concat([cbp1, cbp2]).reset_index()

    # It's gnarly
    df["merge_key"] = df["bill_id"].apply(standardize_bill_id)
    cbp["merge_key"] = cbp["BillID"].apply(standardize_bill_id)

    # Let's do the merge, and then within each duplicate section find the minimum Levenshtein distance
    merge_df = pd.merge(df, cbp, how="left", on="merge_key")

    # Within each multi-match we find the best match by length-normalized Levenshtein distance
    dup_ids = (
        merge_df["merge_key"]
        .value_counts()[merge_df["merge_key"].value_counts() > 1]
        .index.tolist()
    )
    drop_idxs = []
    max_dists = []
    for dup_id in tqdm(dup_ids):
        ref_text = df.loc[df["merge_key"].eq(dup_id), "text"].item()
        cand_rows = merge_df.loc[merge_df["merge_key"].eq(dup_id), :]
        dists = [Lv_ratio(ref_text, comp) for comp in cand_rows["Title"]]
        idxs = list(range(len(dists)))
        idxs.pop(dists.index(max(dists)))
        max_dists.append(max(dists))
        drop_idxs += cand_rows.index[idxs].tolist()
    df = merge_df.drop(drop_idxs)
    return df


def prep_impute_dw1(vals: pd.Series) -> pd.Series:
    vals = vals.apply(lambda s: float(
        s.replace(",", ".") if isinstance(s, str) else s))
    vals = vals.apply(lambda x: np.nan if x == -99.0 else x)
    mean = vals[vals.notna()].mean()
    vals[vals.isna()] = mean
    return vals


# Adding embeddings
def calculate_cosine_distance(
    model: SentenceTransformer | str,
    target_text: str,
    texts: List[str],
    batch_size: int = 128,
    random_seed: int = 1234,
) -> np.ndarray:
    torch.manual_seed(random_seed)
    # Init model
    if isinstance(model, str):
        model = SentenceTransformer(model)

    # Target embed
    target_embed = model.encode(target_text, show_progress_bar=False)

    # Embed sentences
    with torch.no_grad():
        embeds = model.encode(texts, batch_size=batch_size)

    # Calculate distances
    distances = np.apply_along_axis(
        func1d=lambda embed: cosine(target_embed, embed), axis=1, arr=embeds
    )

    return distances


def main():
    # Step 1: Prep source
    logger.info("Preparing source data")
    data_file = data_dir / "cbp_data_no_labels.csv"
    keep = [
        "majortopic",
        "text",
        "chamber",
        "party",
        "pass_h",
        "pass_s",
        "bill_id",
        "year",
        "cong",
    ]
    data_ops = {
        "label": {"col": "majortopic", "op": lambda x: x == 1},
        "senate": {"col": "chamber", "op": lambda x: x == 2},
        "democrat": {"col": "party", "op": lambda x: x == 100},
    }
    df = prep_source_data(data_file, keep, data_ops)

    # Step 2: Add LLM results
    logger.info("Adding LLM results")
    results = [
        Result(
            0,
            data_dir / "cbp_data_no_labels_text-davinci-003_cbp_binary_macro_0shot.csv",
            "q_text-davinci-003_0shot",
        ),
        Result(
            5,
            data_dir / "cbp_data_no_labels_text-davinci-003_cbp_binary_macro_5shot.csv",
            "q_text-davinci-003_5shot",
        ),
    ]
    df = add_llm_predictions(df, results)
    out_vars = df.columns.tolist()

    # Step 3: Merge in CBP data
    logger.info("Adding additional covariates from CBP data")
    df = add_extra_cbp_labels(df)
    df.loc[:, "dw1"] = prep_impute_dw1(df["DW1"])  # Impute DW1
    df.dropna(axis=1, inplace=True)  # Drop columns we're not using/have NAs
    out_vars = out_vars + ['dw1', 'Postal']

    # Step 4: Embeddings for cosine distances
    logger.info("Generating embeddings for cosine distance metric.")
    # Model
    embed_model = SentenceTransformer("all-mpnet-base-v2")
    # target description
    target_text = "Issues related to general domestic macroeconomic policy inflation, cost of living, prices, interest rates, the unemployment rate, impact of unemployment the monetary policy, central bank, the treasury, public debt, budgeting, efforts to reduce deficits tax policy, the impact of taxes, tax enforcement manufacturing policy, industrial revitalization growth wage or price control, emergency price controls or other macroeconomics subtopics."
    # Time embedding process
    start_time = datetime.now()
    df.loc[:, "dist_macro"] = calculate_cosine_distance(
        embed_model, target_text, df["text"].tolist(), batch_size=128,
    )
    logger.info(f"Total time to run embeddings: {datetime.now()-start_time}.")
    out_vars = out_vars + ['dist_macro']

    # Step 5: Reform and export
    logger.info(f"Creating final outputs")
    macrodf = df.loc[df["majortopic"].eq(1), out_vars]
    otherdf = df.loc[df["majortopic"].ne(1), out_vars]

    # Create splits/samples
    balanced_df = pd.concat(
        [macrodf, otherdf.sample(5000, random_state=1234)], ignore_index=True
    )
    imbalanced_df = pd.concat(
        [macrodf.iloc[:1000, :], otherdf], ignore_index=True)

    # Save
    logger.info(
        "Saving final outputs to cbp_easy_with_proxies.csv and cbp_imbalanced_with_proxies.csv"
    )
    balanced_df.to_csv(output_dir / "cbp_easy_with_proxies.csv", index=False)
    imbalanced_df.to_csv(
        output_dir / "cbp_imbalanced_with_proxies.csv", index=False)


if __name__ == "__main__":
    main()
