#!/usr/bin/python
# coding=utf-8
#
# @title: Data Extraction and Preparation from Ziems et al 2023
"""
Before you run this script, clone their repo using:
git clone git@github.com:SALT-NLP/LLMs_for_CSS  llms_for_css
"""

import logging
import pandas as pd
from pathlib import Path

from llms_for_css import mappings as llm_mappings
from llms_for_css.eval_significance import DATASETS, MODELS, MAPPINGS, clean

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(name)s - %(message)s",
    datefmt="%m/%d/%Y %H:%M:%S",
    level=logging.INFO,
)
logger = logging.getLogger()


def answer_path_extractor(row: pd.Series, model_name: str, data_dir: Path):
    answer_path = str(data_dir / f"{row['subdir']}/{row['base_answer_key']}")
    if model_name == "chatgpt" or "text-" in model_name:
        answer_path = answer_path + "-" + model_name
    elif "flan" in model_name:
        answer_path = answer_path + "-" + model_name.split("/")[-1]
    answer_path = Path(answer_path)
    if not answer_path.exists():
        logging.warning(f"Answer path does not exist: {answer_path}")
        return None
    return answer_path.stem


def answer_processing(row: pd.Series, model: str, data_dir: Path) -> pd.DataFrame:
    if row[model] is None:
        return None
    # Get label map
    if row['name'] in MAPPINGS:
        mapping = MAPPINGS[row['name']]
    else:
        mapping = {}
    # model_short_name
    short_name = model.split('/')[1] if '/' in model else model
    # Get file path to model
    fp = data_dir/f"{row['subdir']}/{row[model]}"
    df = pd.read_csv(fp, sep="\t",
                     names=["idx", "gold", f"q_{short_name}"],
                     on_bad_lines="skip")
    df.loc[:, f"q_{short_name}"] = df[f"q_{short_name}"].apply(
        lambda x: clean(x, mapping))
    df.loc[:, "gold"] = df['gold'].apply(lambda x: clean(x, mapping))
    return df


def dataset_constructor(row: pd.Series, data_dir: Path) -> pd.DataFrame:
    basedir = data_dir / row.subdir
    data = pd.read_json(basedir/row['test_data'])
    answers = [answer_processing(row, m, data_dir) for m in MODELS]
    df_ans = answers[0]
    for df in answers[1:]:
        if df is not None:
            df_ans = pd.merge(df_ans, df, on=['idx', 'gold'], how='outer')
        else:
            continue
    data = pd.merge(
        data.reset_index().rename({'index': 'original_index'}, axis=1),
        df_ans.set_index('idx'),
        left_index=True, right_index=True
    )
    return data

# %%


def main():
    tasks = DATASETS
    task_df = pd.DataFrame(data=dict(name=tasks))

    # Copy their data into this directory
    data_dir = Path('llms_for_css/css_data')
    assert data_dir.exists(), "Please first clone the required repo: `git clone git@github.com:SALT-NLP/LLMs_for_CSS  llms_for_css`"

    # Manually mapping the directories in their repo
    dir_map = {
        'mrf-classification': 'mrf',
        'mrf-explanation': 'mrf',
        'flute-classification': 'flute',
        'flute-explanation': 'flute',
        'humor': 'reddit_humor',
        'politeness': 'wiki_politeness',
        'hate': 'implicit_hate',
        'power': 'wiki_corpus',
        'reframe': 'positive_reframing',
        'stance': 'supreme_corpus'}

    task_df['subdir'] = task_df['name'].apply(lambda d: dir_map.get(d, d))

    answer_map = {
        'mrf-classification': 'answer-classification',
        'mrf-explanation': 'answer-explanation',
        'flute-classification': 'answer-classification',
        'flute-explanation': 'answer-explanation'}

    task_df['base_answer_key'] = task_df['name'].apply(
        lambda d: answer_map.get(d, 'answer'))

    test_map = {
        'mrf-classification': 'test-classification',
        'mrf-explanation': 'test-explanation',
        'flute-classification': 'test-classification',
        'flute-explanation': 'test-explanation'}

    task_df['test_data'] = task_df['name'].apply(
        lambda d: test_map.get(d, 'test')+'.json')

    for model in MODELS:
        task_df[f"{model}"] = task_df.apply(
            lambda row: answer_path_extractor(row, model, data_dir), axis=1)

    # semeval_stance had a mismapped value
    MAPPINGS['semeval_stance']['nan'] = 'c'

    # Build dict of dataframes
    out_frame = {}
    for _, row in task_df.iterrows():
        out_frame[row['name']] = dataset_constructor(row, data_dir)

    # Sanitize and print
    Path("reconstructed_datasets").mkdir(exist_ok=True)
    for n, df in out_frame.items():
        # First sanitize columns
        valid_labels = df['gold'].dropna().unique()
        pred_cols = df.columns[df.columns.str.contains("q")]
        mismatch_cols = pred_cols[df.loc[:, pred_cols].applymap(
            lambda x: x not in valid_labels).any()]
        if len(mismatch_cols):
            logging.warning(
                f"Dataset {n} columns {mismatch_cols.tolist()} missing")
        df.drop(columns=mismatch_cols, inplace=True)
        df.to_csv(f"reconstructed_datasets/{n}.csv")
        df.to_json(f"reconstructed_datasets/{n}.json")

    # Finally a summary
    task_df['n_rows'] = task_df['name'].apply(lambda n: len(
        pd.read_json(f"reconstructed_datasets/{n}.json")))
    task_df['n_classes'] = task_df['name'].apply(lambda n: len(
        pd.read_json(f"reconstructed_datasets/{n}.json")['gold'].unique()))
    print(task_df[['name', 'subdir', 'n_rows', 'n_classes']
                  ].sort_values('n_rows').to_string(index=False))
    task_df.to_csv('./task_overview.csv', index=False)


if __name__ == '__main__':
    main()
