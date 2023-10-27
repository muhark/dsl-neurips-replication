from __future__ import annotations
import pandas as pd
from pathlib import Path
from typing import List

def format_bias_sd(rows: pd.Series,
                   estim_order: List[str]=['SO', 'GSO', 'SSL', 'DSL']
                   ) -> pd.Series:
    row = rows['mean']
    sds = rows['std']
    index_best = row.idxmin() # Get lowest bias
    best_bias = row.loc[index_best] # Store lowest bias for comparison
    for idx, x in enumerate(row):
        if x - best_bias <= 0.001: # Within 0.1% of best bias
            row[idx] = r"\valbest{\makecell{" + f"{100*x:.1f}"+ r"\\" + f"({100*sds[idx]:.1f})" + r"}}"
        else:
            row[idx] = r"\makecell{"+f"{100*x:.1f}"+ r"\\" + f"({100*sds[idx]:.1f})"+r"}"
    return row[estim_order]

def format_coverage_sd(rows: pd.Series,
                       estim_order: List[str]=['SO', 'GSO', 'SSL', 'DSL']
                       ) -> pd.Series:
    row = rows['mean']
    sds = rows['std']
    for idx, x in enumerate(row):
        if x >=0.945:
            row[idx] = r"\valgood{\makecell{" + f"{100*x:.1f}"+ r"\\" + f"({100*sds[idx]:.1f})" + r"}}"
        else:
            row[idx] = r"\makecell{"+f"{100*x:.1f}"+ r"\\" + f"({100*sds[idx]:.1f})"+r"}"
    return row[estim_order]


def format_rmse_sd(rows: pd.Series,
                   avg_dsl_rmse: float,
                   estim_order: List[str]=['SO', 'GSO', 'SSL', 'DSL']
                   ) -> pd.Series:
    row = rows['mean']
    sds = rows['std']
    index_best = row.idxmin()
    best_rmse = row.loc[index_best]
    row[r'$\frac{\text{DSL}}{\text{GSO}}$'] = r"\makecell{"+f"{row['DSL']/row['GSO']:.2f}"+ r"}"
    for idx, x in enumerate(row[:4]):
        # If within avg_dsl_rmse of best_rmse: 
        if x - best_rmse <= avg_dsl_rmse:
            row[idx] = r"\valmid{\makecell{" + f"{100*x:.2f}"+ r"\\" + f"({100*sds[idx]:.2f})" + r"}}"
        else:
            row[idx] = r"\makecell{"+f"{100*x:.1f}"+ r"\\" + f"({100*sds[idx]:.2f})"+r"}"
    return row[estim_order+[r'$\frac{\text{DSL}}{\text{GSO}}$']]

def create_tables(frame_file: Path|str) -> None:
    """Nasty latex table generation"""

    mapping_data = [
        ['mrf_classification', 'mrf (misinformation)', 'Misinfo.', 77.6, 2, 77.6],
        ['conv_go_awry', 'Toxicity (conv_go_awry)', 'Toxic.', 56.6, 2, 56.6],
        ['humor', 'Humor', 'Humor', 59, 2, 58.8],
        ['persuasion', 'Persuasion', 'Pers. I', 51.6, 2, 53.2],
        ['flute_classification', 'Figurative (flute)', 'Figur.', 64, 4, 64],
        ['emotion', 'emotion', 'Emotion', 70.3, 6, 70.3],
        ['semeval_stance', 'Stance (semival stance)', 'Stance', 72, 3, 55.4],
        ['power', 'Power', 'Power', 61.6, 2, 60.8],
        ['politeness', 'Politeness', 'Polite.', 59.2, 3, 52.8],
        ['media_ideology', 'Political Ideology (document level)', 'News', 58.8, 3, 40.3],
        ['discourse', 'Discourse', 'Disc.', 52.5, 7, 41.9],
        ['hate', 'Impl. Hate', 'Hate', 36.3, 6, 35.9],
        ['tempowic', 'Semantic Change (tempowic)', 'Seman.', 66.9, 2, 53.7],
        ['talklife', 'Empathy (talklife)', 'Emp.', 39.8, 3, 39.8],
        ['ibc', 'Political Ideology (ibc dataset, utterance level)', 'Books', 57.6, 3, 48.2],
        ['raop', 'Persuasion (raop, utterance level)', 'Pers. II', 51.6, 7, 49.4],
        ['indian_english_dialect', 'dialect', 'Dialect', 23.7, 23, 23.7]
    ]
    mapping_columns = ['original_name', 'datasets', 'short', 'best_model_Acc.', 'Cls.', 'Acc.']
    task_mapping = pd.DataFrame(mapping_data, columns=mapping_columns)

    task_map = task_mapping.set_index('original_name')['short'].to_dict()
    acc_map = task_mapping.set_index('original_name')['Acc.'].apply(lambda s: f"{s:.0f}").to_dict()

    # Here we use the formatters defined above
    frame = pd.read_csv(frame_file, header=[0, 1, 2], index_col=[0, 1, 2])

    # Get average RMSE
    avg_dsl_rmse = frame['rmse']['std']['DSL'].mean()
    # Apply formatters
    frame = pd.concat([
            frame['bias'].apply(format_bias_sd, axis=1),
            frame['coverage'].apply(format_coverage_sd, axis=1),
            frame['rmse'].apply(lambda row: format_rmse_sd(row, avg_dsl_rmse), axis=1)
        ], axis=1)
    frame.columns = pd.MultiIndex.from_tuples(zip(
            4*['Bias' + r" ($\times100$)"] +
            4*['Coverage' + r" ($\times100$)"] +
            5*['RMSE' + r" ($\times100$)"],
        frame.columns
    ))
    frame = frame.reset_index()

    # Shorten surrogate names
    surr_map = {'flan-ul2': 'UL2',
                'all': 'ALL'}

    # Reformat/restructure - this is for aesthetics
    frame.insert(0, ('Dataset', '# of Classes'), frame[('task', '')].apply(task_map.get))
    frame.insert(1, ('LLM', 'Accuracy'), frame[('task', '')].apply(acc_map.get))
    frame.insert(2, ('', 'Surrogate'), frame[('surrogate', '')].apply(lambda s: r"\texttt{"+surr_map.get(s)+r"}"))
    frame.insert(3, ('', 'N Read'), frame[('n_r', '')])
    frame.drop([('task', ''), ('surrogate', ''), ('n_r', '')],
                axis=1, inplace=True)
    frame.set_index([('Dataset', '# of Classes'),
                    ('LLM', 'Accuracy'),
                    ('', 'Surrogate'),
                    ('', 'N Read')],
                    inplace=True)
    frame.index.names = ['Dataset', 'Acc.', 'LLM', '$n_R$']
    frame.sort_values(['Acc.', 'LLM', "$n_R$"], ascending=[False, True, True], inplace=True)

    # Logic for splitting every 3 rows and doing subnumbering.
    letters = 'abcdefghijklmnopqrstuvwxyz'
    letter_counter = 0
    counter = 0
    offset = 0
    datasets_included = []
    out_tex = r'\setlength\tabcolsep{3pt}'+'\n'
    # Generate tables
    for ds in frame.index.get_level_values('Dataset').unique():
        datasets_included.append(ds)
        tex_table = frame.loc[pd.IndexSlice[[ds], :, :]].to_latex(
                    index=True,
                    multirow=True,
                    multicolumn=True,
                    multicolumn_format='c')

        tl = tex_table.split('\n')
        tl.insert(0, r"\begin{table}[!ht]")

        # Logic for decrementing table number
        if letter_counter!=0:
                tl.insert(1, r"\addtocounter{table}{-1}")
                offset = 1
        tl.insert(1+offset, r"\renewcommand{\thetable}{\arabic{table}" + letters[letter_counter] + r"}")
        tl.insert(2+offset, r"\centering"
                            r"\resizebox{\textwidth}{!}{")
        tl[3+offset] = r"\begin{tabular}{llll|llll|llll|llll|l}"

        counter += 1
        if counter==1:
            tl = tl[:-3]
        elif counter==2:
            tl = tl[9+offset:-3]
        elif counter==3:
            # tl = tl[6:]+[r"\newpage", ""]
            tl = tl[9+offset:-2] + [tl[-2]+"}"] + get_caption(datasets_included) + tl[-1:]
            counter = 0
            letter_counter += 1
            datasets_included = []
        tex_table = '\n'.join(tl)
        out_tex += tex_table

    if counter!=0:
        out_tex += r"""
\bottomrule
\end{tabular}}
"""+get_caption(datasets_included)[0]+r"""
\end{table}
"""
        counter = 0

    print(out_tex)

    # Save and done
    out_file = Path('table/measure_table.tex').expanduser()
    out_file.write_text(out_tex)

def get_caption(datasets_included: List[str])-> List[str]:
    out_str = r"\caption{\textbf{Class prevalence estimation} for " + ', '.join(datasets_included) + ("." if datasets_included[-1][-1]!='.' else "") +  r".}"
    return [out_str, r"\end{table}", r"\newpage", ""]

create_tables('table/measurement_frame_table.csv')







# %%
