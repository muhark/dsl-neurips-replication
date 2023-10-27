# Using Imperfect Surrogates for Downstream Inference: Design-based Supervised Learning for Social Science Applications of Large Language Models

This repository provides the replication materials for the paper "Using Large Language Model Annotations for Valid Downstream Statistical Inference in Social Science: Design-Based Semi-Supervised Learning", accepted at NeurIPS 2023.

Authors and Contributors:

- Naoki Egami ([`@naoki-egami`](https://github.com/naoki-egami))
- Musashi Hinck ([`@muhark`](https://github.com/muhark))
- Brandon M. Stewart ([`@bstewart`](https://github.com/bstewart))
- Hanying Wei ([`@weihanying`](https://github.com/weihanying))

_Note that some conventions in the replication code may differ from those in the final published version of the paper. Where they differ, the version in the paper is canonical._


## Repository Structure

We structure the repository into four parts:

- `01_data_and_preprocessing/`: Scripts to download and pre-process datasets used for analysis.
- `02_experiment/`: Scripts and libraries implementing and conducting simulations on HPC.
- `03_postprocessing/`: Post-processing scripts for HPC simulation output
- `04_figures_and_tables/`: Scripts to generate tables and figures for paper and supplementary materials.

Each folder has its own `README.md` which contains specific information about all of the scripts.
In this `README.md` we provide an overview of the process and give instructions on how to use this repo to replicate our analysis.

# Replication

## Dependencies

Our experiments were developed in the Python and R languages on MacOS and Ubuntu Linux, and executed on an HPC running RHEL-like OS (specific to HPC, so cannot reveal for anonymity reasons).

The replication code has been tested using the `jupyter/datascience-notebook` [Docker image](https://hub.docker.com/r/jupyter/datascience-notebook/tags/).
The environment can be created using the following command on a system with Docker installed:

```{sh}
 docker run \
         --gpus all --ipc=host \
         -d -p 8858:8888 \
         -v $HOME:/home/jovyan/work:z \
         -e GRANT_SUDO=yes \
         -e JUPYTER_ENABLE_LAB=yes \
         --user root \
         --name dsl_replicate \
         jupyter/datascience-notebook:latest
```

Windows users are kindly advised to use Docker or WSL to run the replication as compatibility with Windows-based systems has not been tested.

### Python

The user can replicate our Python environment using the `environment.yml` in this directory:

```{sh}
mamba env create --file environment.yml
```

If the user prefers a different setup, these are the libraries we use.  All libraries were download from the `conda-forge` channel.

- `python==3.11` (Earlier versions of Python will require the user to import `annotations` from `__future__`)
- `scipy`
- `pandas`
- `openai`
- `langchain`
- `tqdm`
- `tenacity`
- `datasets`
- `Levenshtein`
- `pytorch-gpu` (Note that CPU-only `pytorch` is also suitable, as the amount of GPU compute used is minimal.)
- `sentence_transformers`

### R

The following libraries are used. The R version may not be essential, other than the use of the `|>` operator.

- `R==4.2.3`
- `survey`
- `grf`
- `MASS`
- `boot`
- `doSNOW`
- `stringr`
- `dplyr`
- `tibble`
- `readr`

For convenience:

```{r}
install.packages(c(
    "survey",
    "grf",
    "MASS",
    "boot",
    "doSNOW",
    "stringr",
    "dplyr",
    "tibble",
    "readr"))
```



## Running the Code

Navigate to each subdirectory of this folder and follow the local `README.md` for instructions to run each segment.
