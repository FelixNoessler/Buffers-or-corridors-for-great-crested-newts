import pandas as pd

data_concat = pd.read_csv('../data/recolonization_experiment_0.csv', index_col=0)

for i in range(1, 4):
    data_i = pd.read_csv(f'../data/recolonization_experiment_{i}.csv', index_col=0)
    data_concat = pd.concat([data_concat, data_i])

data_concat.to_csv('../data/concat_data.csv')
