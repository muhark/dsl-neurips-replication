#!/usr/bin/python
#
# @title: Congressional Bills Project Data Preparation Script
"""
Script for downloading and preparing the Congressional Bills dataset.
"""

import pandas as pd
import logging
from pathlib import Path
from typing import List, Dict

# Logger init
logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(name)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)
logger = logging.getLogger()

# Output management
output_dir = Path.cwd() / "cbp_data"
output_dir.mkdir() if not output_dir.exists() else None
out_file = output_dir / "cbp_data_no_labels.csv"

# Data source URL
data_link = "https://comparativeagendas.s3.amazonaws.com/datasetfiles/US-Legislative-congressional_bills_19.3_3_2.csv"

# Some objects for your convenience
cap_codes = {
    1: "Macroeconomics",
    2: "Civil Rights",
    3: "Health",
    4: "Agriculture",
    5: "Labor",
    6: "Education",
    7: "Environment",
    8: "Energy",
    9: "Immigration",
    10: "Transportation",
    12: "Law and Crime",
    13: "Social Welfare",
    14: "Housing",
    15: "Domestic Commerce",
    16: "Defense",
    17: "Technology",
    18: "Foreign Trade",
    19: "International Affairs",
    20: "Government Operations",
}

keep_cols = [
    "majortopic",
    "description",
    "chamber",
    "party",
    "pass_h",
    "pass_s",
    "bill_id",
    "year",
    "cong",
]

sampling_args = {
    "macro": {"majortopic": [1], "n": 5000},
    "other": {"majortopic": [12, 16, 19], "n": 3000},
}


# Steps as functions
def download_cbp_data(data_link: str) -> pd.DataFrame:
    return pd.read_csv(data_link, low_memory=False)


def preprocess_cbp_data(
    raw_data: pd.DataFrame,
    keep_cols: List[str],
    sampling_args: Dict,
    random_seed: int = 1234,  # This is generally what we use in this project
) -> pd.DataFrame:
    """
    This function contains the preprocessing steps on the downloaded CBP data.
    1. Select `keep_cols`
    2. Filter rows containing NA values in `keep_cols`
    3. Drop duplicates on text column
    4. Randomly sample in the key major topics using `sampling_args`.

    `sampling args` is a nested dictionary structure (designed to be passable as a json if needed):

    ```
    sampling_args = {
        'macro': {                          # Arbitrary name for readability
            'majortopic': [1],              # Which major CAP codes as list of int (see `cap_codes`)
            'n': 5000                       # Number of samples
        },
        [...]
    ```
    """
    # Drop rows with NAs in key columns
    df = raw_data.loc[:, keep_cols]
    df.dropna(inplace=True)
    # Renaming this for consistency
    df.rename({"description": "text"}, axis=1, inplace=True)
    # Keep only first entry for each text (we need entropy)
    df.drop_duplicates(subset=["text"], inplace=True)
    # Sample subsets
    subsets = []
    for (
        _,
        sargs,
    ) in sampling_args.items():
        for topic in sargs["majortopic"]:
            logger.info(f"Creating sample for topic {topic}...")
            subsets.append(
                df.loc[df["majortopic"].eq(topic), :].sample(
                    sargs["n"], replace=False, random_state=random_seed
                )
            )
    label_df = pd.concat(subsets, ignore_index=True)
    return label_df


def main():
    # Check if already downloaded
    if out_file.exists():
        logger.warning(f"File already exists at {out_file}!")

    # Download Data
    logger.info(f"Downloading data from {data_link}")
    raw_data = download_cbp_data(data_link)

    # Pre-Processing
    logger.info("Filtering and sampling data.")
    label_df = preprocess_cbp_data(
        raw_data, keep_cols, sampling_args, random_seed=1234)

    # Save
    logger.info(f"Saving output to {out_file}")
    label_df.to_csv(out_file, index=False)

    logger.info(f"CBP Download Complete!")


if __name__ == "__main__":
    main()
