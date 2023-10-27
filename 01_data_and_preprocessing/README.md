# `01_data`

This folder contains the scripts for downloading and preprocessing the data that was used in the simulations.

# Structure

- `logit`: contains scripts for the data used for the logistic regression experiment in the paper.
- `measurement`: contains scripts for the data used for the logistic regression experiment in the paper.

The scripts are as follows:

- `logit/`
    - [`01_download_data.py`](#01_download_data.py)
    - [`02_llm_labels.py`](#02_llm_labels.py)
    - [`03_additional_covariates.py`](#03_additional_covariates.py)
    - [`cbp_data`](#cbp_data)
      - [`cbp_easy_with_proxies.csv`](#cbp_easy_with_proxies.csv)
      - [`cbp_imbalanced_with_proxies.csv`](#cbp_imbalanced_with_proxies.csv)
    - [`llm_configs`](#llm_configs)
      - [`cbp_binary_macro_0shot.txt`](#cbp_binary_macro_0shot.txt)
      - [`cbp_binary_macro_5shot.txt`](#cbp_binary_macro_5shot.txt)
      - [`model_args.json`](#model_args.json)
- `measurement/`
    - [`04_extract_css_data.py`](#04_extract_css_data.py)
    - [`05_binarize_data.py`](#05_binarize_data.py)

## `logit/`

### `01_download_data.py`

This script downloads the Comparative Agendas Project version of the Congressional Bills Project data and generates the subset of rows that are used for this analysis. Note that at this point we do not split the data into the balanced and imbalanced versions.

The data is saved into the `cbp_data` subdirectory as `cbp_data_no_labels.csv`.

Usage:

```{sh}
python 01_download_data.py
```

### `02_llm_labels.py`

This is a command-line script for conducting zero- and few-shot classification using OpenAI models on either local csv/json files or datasets on HuggingFace.

Note that in the current implementation the exemplars for few-shot classification are fixed and read from a text file, and the arguments to the OpenAI API are read from a json config. Both are contained in the `llm_configs` subdirectory.


Because reproducing 14k predictions on the OpenAI API is time-consuming (and not a trivial cost), we provide the outputs of the script for replication purposes:

- `cbp_data/cbp_data_no_labels_text-davinci-003_cbp_binary_macro_0shot.csv`
- `cbp_data/cbp_data_no_labels_text-davinci-003_cbp_binary_macro_5shot.csv`

The commands used to generate these datasets were as follows:

```{sh}
python 02_llm_labels.py \
    --dataset_name_or_path cbp_data/cbp_data_no_labels.csv \
    --model_args llm_configs/model_args.json \
    --prompt_template llm_configs/cbp_binary_macro_0shot.txt
```

```{sh}
python 02_llm_labels.py \
    --dataset_name_or_path cbp_data/cbp_data_no_labels.csv \
    --model_args llm_configs/model_args.json \
    --prompt_template llm_configs/cbp_binary_macro_5shot.txt
```

For replication, the researcher may want to add the  `--testing` flag, which conducts just two predictions and creates a separate file suffixed with `*_test.csv`.

Finally, the model configuration and prompts used were as follows:

`llm_configs/model_args.json`:

```{json}
{"engine": "text-davinci-003", "max_tokens": 1, "temperature": 0, "logprobs": 5}
```

`llm_configs/cbp_binary_macro_0shot.txt`

```{txt}
Does the following text relate to the economy? (True/False)

text: """
{content}
"""

label:
```

`llm_configs/cbp_binary_macro_5shot.txt`

Note that these exemplars are fixed, and cherry-picked from a random sample from eligible rows in the original dataset that were not included in the sample.


```{txt}
Does the following text relate to the economy? (True/False)

text: """
To provide that Federal expenditures shall not exceed Federal revenues, except in time of war or grave emergency declared by the Congress, and to provide for systematic reduction of the public debt
"""

label: True

text: """
To amend the Internal Revenue Act of 1954 to increase from $600 to $1,200 the personal income tax exemptions of a taxpayer (including the exemtion for a spouse, the exemption for a dependent, and the additional exemptions for old age and blindness)
"""

label: True

text: """
A bill to amend the Internal Revenue Code of 1954 to provide special loss carryover rules for insurance companies.
"""

label: False

text: """
To provide individuals with access to health information of which they are a subject, to ensure personal privacy, security, and confidentiality with respect to health related information in promoting the development of a nationwide interoperable health information infrastructure, to impose criminal and civil penalties for unauthorized use of personal health information, to provide for the strong enforcement of these rights, to protect States' rights, and for other purposes.
"""

label: True

text: """
A bill to amend title XVI of the Social Security Act to reduce from 21 to 18 the age at which a disabled child need no longer include his parents' income in determining his eligibility for supplemental security income benefits or the amount of such benefits.
"""

label: False

text: """
{content}
"""

label: 
```

### `03_additional_covariates.py`

This script adds in the additional covariates that are used for the downstream analysis.

The key steps in this script are:

1. Converting existing covariates to binary 0/1 outcomes (`prep_source_data`)
2. Merging in the predictions of the LLM generated by the `02_llm_labels.py`.
3. Adding further covariates from a version of the CBP dataset with more covariates.
4. Adding a similarity score between each document and the target class description using the cosine distance of sentence transformer embeddings.
5. Generating splits and saving.

Step 1 is done with straightforward lambda operations (lines 212-216).

Step 2 is slightly more complicated. The function `add_llm_predictions` takes the output of `02_llm_labels.py` and extracts three values:

- `q_gpt3_*shot`: the most likely token
- `ppos_gpt3_*shot`: the probability assigned to the most likely token normalized by `ptotal_gpt3_*shot`
- `ptotal_gpt3_*shot`: the total probability mass assigned to tokens matching some permutation of `True` or `False` (see lines 64-65)

Ultimately we do not use the token probabilities in downstream analyses, but the implementation of our debiasing estimators allows for non-integer inputs as surrogates.

Step 3 merges the two versions of the datasets on the Bill ID, using minimum normalized Levenshtein distance to resolve cases where there are no exact matches but many potential matches. Manual checking shows that this works well, as the mismatches are generally due to entry errors (such as writing `H` instead of `HR` to indicate that a bill is from the House of Representatives).

The variable added in from this data is `DW1`, which is the first DW-Nominate score of the proposing legislator. Where missing, we use mean imputation on the column.

Step 4 uses the `MPNet` sentence transformer model to produce embeddings for a 

These come from the CBP version of the dataset (as opposed to the one from the comparative agendas project, which is a bit cleaner).

### `cbp_data/cbp_easy_with_proxies.csv`

This is the input data we used for the `balanced` task for the logit problem.

Balanced 0shot Confusion Matrix:

|            | Predicted False (TN) | Predicted True (FP) |
| ---------- | ------------------- | ------------------- |
| Actual False (TN) | 4771                  | 229                  |
| Actual True (FN)   | 2960                  | 2040                |

Balanced 0shot Classification Report:

|        | precision | recall | f1-score | support |
| ------ | --------- | ------ | -------- | ------- |
| False  | 0.62      | 0.95   | 0.75     | 5000    |
| True   | 0.90      | 0.41   | 0.56     | 5000    |
| ------ | --------- | ------ | -------- | ------- |
| accuracy |           |        | 0.68     | 10000   |
| macro avg | 0.76      | 0.68   | 0.66     | 10000   |
| weighted avg | 0.76   | 0.68   | 0.66     | 10000   |

Balanced 5shot Confusion Matrix:

|            | Predicted False (TN) | Predicted True (FP) |
| ---------- | ------------------- | ------------------- |
| Actual False (TN) | 4468                  | 532                  |
| Actual True (FN)   | 1091                  | 3909                |

Balanced 5shot Classification Report:

|        | Precision | Recall | F1-Score | Support |
| ------ | --------- | ------ | -------- | ------- |
| False  | 0.80      | 0.89   | 0.85     | 5000    |
| True   | 0.88      | 0.78   | 0.83     | 5000    |
| ------ | --------- | ------ | -------- | ------- |
| Accuracy |           |        | 0.84     | 10000   |
| Macro Avg | 0.84      | 0.84   | 0.84     | 10000   |
| Weighted Avg | 0.84   | 0.84   | 0.84     | 10000   |



### `cbp_data/cbp_imbalanced_with_proxies.csv`

This is the input data we used for the imbalanced task for the logit problem.

The LLM label accuracy summarized:

Imbalanced 0shot Confusion Matrix:

|            | Predicted False (TN) | Predicted True (FP) |
| ---------- | ------------------- | ------------------- |
| Actual False (TN) | 8617                  | 383                  |
| Actual True (FN)   | 584                  | 416                |

Imbalanced 0shot Classification Report:

|        | Precision | Recall | F1-Score | Support |
| ------ | --------- | ------ | -------- | ------- |
| False  | 0.94      | 0.96   | 0.95     | 9000    |
| True   | 0.52      | 0.42   | 0.46     | 1000    |
| ------ | --------- | ------ | -------- | ------- |
| Accuracy |           |        | 0.90     | 10000   |
| Macro Avg | 0.73      | 0.69   | 0.70     | 10000   |
| Weighted Avg | 0.89   | 0.90   | 0.90     | 10000   |

Imbalanced 5shot Confusion Matrix:

|        | Precision | Recall | F1-Score | Support |
| ------ | --------- | ------ | -------- | ------- |
| False  | 0.97      | 0.89   | 0.93     | 9000    |
| True   | 0.45      | 0.77   | 0.57     | 1000    |
| ------ | --------- | ------ | -------- | ------- |
| Accuracy |           |        | 0.88     | 10000   |
| Macro Avg | 0.71      | 0.83   | 0.75     | 10000   |
| Weighted Avg | 0.92   | 0.88   | 0.89     | 10000   |

Imbalanced 5shot Classification Report:

|            | Predicted False (TN) | Predicted True (FP) |
| ---------- | ------------------- | ------------------- |
| Actual False (TN) | 8036                  | 964                  |
| Actual True (FN)   | 226                  | 774                |

## `measurement/`

### `04_extract_css_data.py`

This script processes and extracts the replication data from Ziems et al. (2023)'s github.

Note that in order to run this code, you should first clone their repo (with the name `llms_for_css`) into the directory:

```{sh}
git clone git@github.com:SALT-NLP/LLMs_for_CSS  llms_for_css
```

### `05_binarize_data.py`

This script adds cosine distances from target class labels using `sentence_transformers`. See `css_mappings.py` for the target class labels. Datasets with more than two classes are binarized.

This produces datasets in the format expected by our experiment scripts in the next section. The processed datasets are stored in `binarized_datasets/`.


## Usage

### Logit

(Assuming you are in `./logit`)

Step 1: Download datasets.

```{sh}
python 01_download_data.py
```

Step 2: Generate zero- and five-shot classifications

```{sh}
python 02_llm_labels.py \
    --dataset_name_or_path cbp_data/cbp_data_no_labels.csv \
    --model_args llm_configs/model_args.json \
    --prompt_template llm_configs/cbp_binary_macro_0shot.txt \
    --testing
```

Step 3: Add sentence embeddings and other covariates

```{sh}
python 03_additional_covariates.py
```

### Measurement

(Assuming you are in `./measurement`)

Step 1: Clone the Ziems et al (2023) repo:

```{sh}
git clone git@github.com:SALT-NLP/LLMs_for_CSS  llms_for_css
```

Step 2: Extract data

```{sh}
python 04_extract_css_data.py
```

Step 3: Binarize datasets and prepare for analysis

```{sh}
python 05_binarize_data.py
```
