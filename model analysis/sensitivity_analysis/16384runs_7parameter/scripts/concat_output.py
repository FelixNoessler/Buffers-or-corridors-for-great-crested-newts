import pandas as pd

ind = [i * 256 for i in range(0, 64 + 1)]
data_concat = pd.read_csv(f'../data/all_files/results_{ind[0]}_{ind[0+1]}.csv', index_col=0)

for i in range(1, len(ind)-1):
    data_i = pd.read_csv(f'../data/all_files/results_{ind[i]}_{ind[i+1]}.csv', index_col=0)
    data_concat = pd.concat([data_concat, data_i])

data_concat.to_csv('../data/concat_data.csv')
