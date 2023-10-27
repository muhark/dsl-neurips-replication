from __future__ import annotations
import pandas as pd
from pathlib import Path
from typing import List

def format_bias_sd(rows: pd.Series,
                   estim_order: List[str]=['SO', 'GSO', 'SSL', 'DSL']
                   ) -> pd.Series:
    # This is a bit hacky--the `rows` have two index levels.
    row = rows['mean']
    sds = rows['std']
    index_best = row.idxmin() # Get lowest bias
    best_bias = row.loc[index_best] # Store lowest bias for comparison
    for idx, x in enumerate(row):
        if x - best_bias <= 0.1: # Within 0.1% of best bias
            row[idx] = r"\valbest{\makecell{" + f"{x:.2f}"+ r"\\" + f"({sds[idx]:.2f})" + r"}}"
        else:
            row[idx] = r"\makecell{"+f"{x:.2f}"+ r"\\" + f"({sds[idx]:.2f})"+r"}"
    return row[estim_order]

def format_coverage_sd(rows: pd.Series,
                       estim_order: List[str]=['SO', 'GSO', 'SSL', 'DSL']
                       ) -> pd.Series:
    row = rows['mean']
    sds = rows['std']
    for idx, x in enumerate(row):
        if x >=0.945:
            row[idx] = r"\valgood{\makecell{" + f"{100*x:.3g}"+ r"\\" + f"({100*sds[idx]:.3g})" + r"}}"
        else:
            row[idx] = r"\makecell{"+f"{100*x:.3g}"+ r"\\" + f"({100*sds[idx]:.3g})"+r"}"
    return row[estim_order]


def format_rmse_sd(rows: pd.Series,
                   avg_dsl_rmse: float,
                   estim_order: List[str]=['SO', 'GSO', 'SSL', 'DSL']
                   ) -> pd.Series:
    row = rows['mean']
    sds = rows['std']
    index_best = row.idxmin()
    best_rmse = row.loc[index_best]
    # Add DSL/GSO comparison
    row[r'$\frac{\text{DSL}}{\text{GSO}}$'] = r"\makecell{"+f"{row['DSL']/row['GSO']:.2f}"+ r"}"
    for idx, x in enumerate(row[:4]):
        if x - best_rmse <= avg_dsl_rmse:
            row[idx] = r"\valmid{\makecell{" + f"{x:.2f}"+ r"\\" + f"({sds[idx]:.2f})" + r"}}"
        else:
            row[idx] = r"\makecell{"+f"{x:.2f}"+ r"\\" + f"({sds[idx]:.2f})"+r"}"
    return row[estim_order+[r'$\frac{\text{DSL}}{\text{GSO}}$']]

def create_tables(frame_file: Path|str) -> None:
    """Nasty latex table generation"""
    task_map = {'balanced': '1:1', 'imbalanced': '1:9'}
    acc_map = {('0shot', 'balanced'): 68,
               ('5shot', 'balanced'): 84,
               ('0shot', 'imbalanced'): 90,
               ('5shot', 'imbalanced'): 88}

    # Here we use the formatters defined above
    # frame = boot_df.groupby(['task', 'surrogate', 'n_r', 'estimator']).agg(['mean', 'std']).unstack()
    frame = pd.read_csv(frame_file, header=[0, 1, 2], index_col=[0, 1, 2])
    avg_dsl_rmse = frame['rmse']['std']['DSL'].mean()
    frame = pd.concat([
            frame['bias'].apply(format_bias_sd, axis=1),
            frame['coverage'].apply(format_coverage_sd, axis=1),
            frame['rmse'].apply(lambda row: format_rmse_sd(row, avg_dsl_rmse), axis=1)
        ], axis=1)
    frame.columns = pd.MultiIndex.from_tuples(zip(
        4*['Bias'] +
        4*['Coverage'+ r" ($\times100$)"] +
        5*['RMSE'],
        frame.columns
    ))
    frame = frame.reset_index()

    # This is ugly
    acc_col = frame[['task', 'surrogate']].apply(lambda x: (x['surrogate'].item(), x['task'].item()), axis=1).apply(acc_map.get)

    # Reformat/restructure - this is for aesthetics
    frame.insert(0, ('Dataset', '# of Classes'), frame[('task', '')].apply(task_map.get))
    frame.insert(1, ('LLM', 'Accuracy'), acc_col)
    frame.insert(2, ('', 'Surrogate'), frame[('surrogate', '')].apply(lambda s: r"\texttt{"+s[0]+r"}"))
    frame.insert(3, ('', 'N Read'), frame[('n_r', '')].replace({1000: '1K'}))
    frame.drop([('task', ''), ('surrogate', ''), ('n_r', '')],
                axis=1, inplace=True)
    frame.set_index([('Dataset', '# of Classes'),
                    ('LLM', 'Accuracy'),
                    ('', 'Surrogate'),
                    ('', 'N Read')],
                    inplace=True)
    frame.index.names = ['Bal', 'Acc.', r'\texttt{shot}', '$n_R$']

    # Generating the table
    out_tex = r'\setlength\tabcolsep{3pt}'+'\n'
    tex_table = frame.to_latex(
                index=True,
                multirow=True,
                multicolumn=True,
                multicolumn_format='c')
    tl = tex_table.split('\n')
    tl.insert(0, r"\begin{table}[!ht]")
    tl.insert(1, r"\centering"
                    r"\resizebox{\textwidth}{!}{")
    tl[2] = r"\begin{tabular}{llll|llll|llll|llll|l}"
    tl.append(r"}\caption{\textbf{Complete logistic regression results.} See text.\label{tab:logitboot}}")
    tl.append(r"\end{table}")

    out_tex += '\n'.join(tl) 

    print(out_tex)

    # Save and done
    out_file = Path('table/logit_table.tex').expanduser()
    out_file.write_text(out_tex)

create_tables('table/logit_frame_table.csv')

